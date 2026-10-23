# 3.3 Seguridad en el Despliegue y Acceso

En la sesión anterior analizamos cómo asegurar la conectividad interna mediante el CNI, CoreDNS y _NetworkPolicies_, y ahora en esta sesión llevaremos ese conocimiento a la práctica al explorar RBAC, _ServiceAccounts_ y mecanismos de autenticación.

## 1. Explicación conceptual

En Kubernetes, la seguridad de acceso y despliegue opera bajo la premisa de que todo punto de acceso —ya sea un ingeniero ejecutando `kubectl` o un microservicio en Java con Quarkus consultando la API— debe ser autenticado y autorizado bajo el principio de mínimo privilegio (_Least Privilege_).

### Control de acceso basado en roles (RBAC)

La autorización en la API del clúster se gestiona mediante cuatro objetos fundamentales:

- **`Role`:** Define un conjunto de permisos (verbos como `get`, `list`, `create`) sobre recursos específicos (`pods`, `services`) dentro de un _namespace_ delimitado.

- **`ClusterRole`:** Define permisos a nivel de todo el clúster (recursos no asociados a _namespaces_ como `nodes`, `persistentvolumes`, o recursos globales en todos los _namespaces_).

- **`RoleBinding`:** Vincula un `Role` o `ClusterRole` a un sujeto (usuario, grupo o `ServiceAccount`) restringiendo el alcance únicamente a un _namespace_ específico.

- **`ClusterRoleBinding`:** Otorga los permisos de un `ClusterRole` a un sujeto en todos los _namespaces_ del clúster.

### Identidad para aplicaciones: ServiceAccounts

Los usuarios humanos suelen autenticarse mediante proveedores OIDC o certificados X.509, pero las cargas de trabajo (_workloads_) utilizan **`ServiceAccounts`**. Cuando un _pod_ se ejecuta con una `ServiceAccount`, Kubernetes inyecta un _JSON Web Token_ (JWT) firmado de corta duración en `/var/run/secrets/kubernetes.io/serviceaccount/token`. Este token le permite a la aplicación realizar peticiones autenticadas contra la API Server de Kubernetes.

### Gestión de datos sensibles e integración con Key Vaults

Los objetos **`Secret`** nativos de Kubernetes guardan datos confidenciales (contraseñas, tokens API). Sin embargo, por defecto están codificados únicamente en `Base64` y se almacenan sin encriptar en `etcd` (a menos que se active _encryption-at-rest_). En entornos de producción cloud-native, la mejor práctica consiste en externalizar el ciclo de vida de los secretos hacia un gestor dedicado (Azure Key Vault, HashiCorp Vault, AWS Secrets Manager) e integrarlos al clúster utilizando controladores como **External Secrets Operator (ESO)** o **Secrets Store CSI Driver**.

### Seguridad de la carga de trabajo y cadena de suministro

- **Pod Security Standards (PSS) & Admission Controllers:** Reemplazaron a las antiguas _PodSecurityPolicies_. PSS categoriza el endurecimiento de los contenedores en tres niveles: _Privileged_ (sin restricciones), _Baseline_ (previene escalación de privilegios conocida) y _Restricted_ (exige ejecución como usuario no-root, aislamiento del sistema de archivos de solo lectura y deshabilitación de capacidades del Kernel).

- **Escaneo y firma de imágenes:** La seguridad de la cadena de suministro (_supply chain_) exige que toda imagen en el _registry_ sea escaneada contra vulnerabilidades conocidas (CVEs) antes del despliegue y validada mediante firmas digitales usando herramientas como **Cosign** / **Sigstore** a través de un _validating admission webhook_ (ej. Kyverno u OPA/Gatekeeper).

## 2. Analogía del mundo real

Imagina la seguridad de un hotel de alta gama:

- **ServiceAccount (La credencial del personal):** Es el gafete con chip que se le entrega a un empleado. La credencial no dice quién es la persona individualmente, sino el rol que cumple durante su turno de trabajo.

- **RBAC (Los permisos del chip):**

  - Un **`Role`** especifica qué puertas abre la tarjeta dentro del piso 3 (_namespace_): la puerta de limpieza y el cuarto de blancos.

  - Un **`RoleBinding`** es el acto de programar la tarjeta del empleado para que funcione específicamente en ese piso 3.

  - Un **`ClusterRoleBinding`** sería entregarle la llave maestra al gerente general para abrir cualquier habitación de cualquier piso de la cadena hotelera.

- **Secrets vs. Key Vaults (La caja fuerte de la habitación vs. el banco):** Dejar un `Secret` codificado en Base64 es como guardar el pasaporte en un cajón con un papel transparente encima: cualquiera que abra el cajón puede leerlo inmediatamente. Usar un _Key Vault_ externo equivale a dejar los valores de gran importancia en la bóveda de un banco y traer al hotel un duplicado temporal mediante un mensajero blindado solo cuando sea estrictamente necesario.

- **Pod Security Standards (Las reglas de protección civil):** Son los inspectores en la puerta del hotel. El nivel _Restricted_ no permite que ningún visitante entre con materiales inflamables, herramientas pesadas o sin identificación verificable, asegurando que nadie pueda tomar el control del inmueble si entra a una habitación.

## 3. Desglose técnico paso a paso

Configuraremos una arquitectura donde un microservicio Quarkus en el _namespace_ `apps` utiliza una **`ServiceAccount`** dedicada para consultar de forma segura únicamente los pods de su propio _namespace_, mientras que el _namespace_ impone el perfil de seguridad **`Restricted`**.

### Paso 1: Configurar el Namespace con Pod Security Standards

Crea el archivo `01-namespace-security.yaml`. Etiquetamos el _namespace_ para obligar a que cualquier _pod_ desplegado cumpla con el estándar _Restricted_.

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: apps
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/enforce-version: latest
    pod-security.kubernetes.io/warn: restricted
```

Aplica el _namespace_:

```bash
kubectl apply -f 01-namespace-security.yaml
```

### Paso 2: Crear el rol RBAC y la ServiceAccount de mínimo privilegio

Crea el archivo `02-rbac-setup.yaml`:

```yaml
# 1. Identidad para la aplicación
apiVersion: v1
kind: ServiceAccount
metadata:
  name: quarkus-monitor-sa
  namespace: apps
---
# 2. Definición del Role (permisos de lectura únicamente sobre Pods)
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-reader-role
  namespace: apps
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "watch"]
---
# 3. Vinculación de la ServiceAccount con el Role
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: read-pods-binding
  namespace: apps
subjects:
- kind: ServiceAccount
  name: quarkus-monitor-sa
  namespace: apps
roleRef:
  kind: Role
  name: pod-reader-role
  apiGroup: rbac.authorization.k8s.io
```

Aplica la configuración de seguridad:

```bash
kubectl apply -f 02-rbac-setup.yaml
```

### Paso 3: Desplegar un pod seguro conforme al estándar Restricted

Crea el archivo `03-secure-deployment.yaml`. La especificación del contenedor incluye un **`securityContext`** estricto para no violar el estándar _Restricted_ impuesto en el _namespace_.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: quarkus-app
  namespace: apps
spec:
  replicas: 1
  selector:
    matchLabels:
      app: quarkus-app
  template:
    metadata:
      labels:
        app: quarkus-app
    spec:
      serviceAccountName: quarkus-monitor-sa
      securityContext:
        runAsNonRoot: true
        runAsUser: 10001
        runAsGroup: 10001
        fsGroup: 10001
        seccompProfile:
          type: RuntimeDefault
      containers:
      - name: app
        image: curlimages/curl:8.5.0
        command: ["sh", "-c", "sleep 3600"]
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop:
            - ALL
```

Aplica el _deployment_:

```bash
kubectl apply -f 03-secure-deployment.yaml
```

### Paso 4: Verificación de la autorización y validación del token

1. **Prueba de acceso autorizado en el namespace local:** Conéctate al pod y realiza una consulta usando el token de la `ServiceAccount` inyectado por el clúster.

    ```bash
    APP_POD=$(kubectl get pod -n apps -l app=quarkus-app -o jsonpath='{.items[0].metadata.name}')

    # Consultar el endpoint de Pods en el namespace 'apps' utilizando el token autenticado
    kubectl exec -it $APP_POD -n apps -- sh -c '
      TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
      curl -s -k -H "Authorization: Bearer $TOKEN" \
        https://kubernetes.default.svc/api/v1/namespaces/apps/pods
    '
    ```

    _Resultado esperado:_ Respuesta HTTP `200 OK` con el listado JSON de los pods del _namespace_ `apps`.

2. **Prueba de denegación de autorización (Mínimo Privilegio):** Intenta consultar los pods del _namespace_ `kube-system` con ese mismo token.

    ```bash
    kubectl exec -it $APP_POD -n apps -- sh -c '
      TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
      curl -s -k -H "Authorization: Bearer $TOKEN" \
        https://kubernetes.default.svc/api/v1/namespaces/kube-system/pods
    '
    ```

    _Resultado esperado:_ Respuesta HTTP `403 Forbidden` (`User "system:serviceaccount:apps:quarkus-monitor-sa" cannot list resource "pods" in API group "" in the namespace "kube-system"`).

### 4. Reto de ingeniería o pregunta de reflexión

**El escenario:**

El equipo de DevOps desplegó un _cluster-autoscaler_ y un sistema de monitoreo en el clúster. Para acelerar las pruebas, un desarrollador configuró la manifestación adjunta binding a la `ServiceAccount` del microservicio:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: global-admin-binding
subjects:
- kind: ServiceAccount
  name: quarkus-monitor-sa
  namespace: apps
roleRef:
  kind: ClusterRole
  name: cluster-admin
  apiGroup: rbac.authorization.k8s.io
```

Días después, se detecta que una vulnerabilidad de tipo _Remote Code Execution_ (RCE) en una librería de terceros expuso la aplicación Quarkus en el _namespace_ `apps`.

**Preguntas para debate:**

1. ¿Qué alcance y nivel de compromiso de seguridad adquirió el atacante al vulnerar la aplicación Quarkus debido a la existencia del `ClusterRoleBinding` mostrado?

2. Si un atacante compromete el pod y lee el token en `/var/run/secrets/kubernetes.io/serviceaccount/token`, ¿cómo ayuda la característica de _Bound Service Account Tokens_ (tokens con límite de tiempo y audiencia específica) a mitigar este riesgo en comparación con los tokens estáticos de versiones antiguas de Kubernetes?

3. ¿Qué cambio estructural realizarías en la definición de RBAC para garantizar que la aplicación vuelva a operar estrictamente bajo el principio de mínimo privilegio sin romper sus funciones de monitoreo local?

> "En la sesión anterior analizamos cómo asegurar el acceso al clúster mediante RBAC, _ServiceAccounts_ y _Pod Security Standards_, y ahora en esta sesión cerraremos la plataforma segura que servirá como base para automatizar despliegues, pipelines e infraestructura como código en la siguiente unidad."
