# **Unidad 3:** Guía de laboratorio integrador: Arquitectura cloud-native segura, resiliente y balanceada

## 1. Objetivo del laboratorio y escenario real

### Escenario de la industria

Retomas `u3-starter`, que hereda la plataforma e-commerce ya desplegada en Kubernetes con `catalog-service` e `inventory-service`. En esta unidad el foco se mueve al flujo de checkout: el equipo necesita exponer y asegurar `payment-service` y el acceso externo al sistema sin romper la continuidad del mismo proyecto integrador. Tras una auditoría de ciberseguridad, el equipo de arquitectura identificó vulnerabilidades críticas en el entorno actual:

1. El tráfico que entra desde internet hacia los microservicios no utiliza encriptación SSL/TLS de extremo a extremo ni dominios estructurados.

2. Todos los _pods_ pueden comunicarse libremente entre sí dentro del clúster sin restricciones de red L3/L4 (ausencia de un modelo _Zero Trust_).

3. Los contenedores se ejecutan como usuario `root` y la aplicación utiliza credenciales con permisos globales de _cluster-admin_.

4. Las imágenes de contenedor se despliegan en producción sin verificación previa de vulnerabilidades (CVEs).

#### Objetivo técnico

Diseñar, desplegar y endurecer la infraestructura del clúster construyendo una arquitectura en capas que integre terminación TLS con Ingress, aislamiento estricto de red L3/L4 mediante _NetworkPolicies_, autorización con RBAC de mínimo privilegio y políticas de seguridad en _pods_ bajo el estándar _Restricted_.

### 2. Prerrequisitos y stack tecnológico

Antes de iniciar el laboratorio, debes verificar que tu entorno local de desarrollo o entorno asignado cumpla con los siguientes elementos instalados y operativos:

- **Orquestador:** Clúster de Kubernetes funcional (`Kind`, `k3s` o `Minikube`) versión 1.28+. Si usas `Kind`, debe estar configurado con soporte para CNI Calico o Cilium.

- **Herramientas CLI:**

  - `kubectl` (v1.28+)

  - `helm` (v3.12+)

  - `openssl`

  - `curl` y `jq`

  - `trivy` (v0.45+)

- **Cargas de trabajo:** Imagen Docker de microservicio en Quarkus o imagen ligera de pruebas (`curlimages/curl`, `nginx:alpine`).

- **Insumos del laboratorio:** Acceso a terminal con privilegios de administración local sobre el clúster.

### 3. Desglose técnico paso a paso (guía hands-on)

```text
                       [ Cliente / NAVEGADOR ]
                                  │
                                  ▼ (HTTPS / TLS :443)
                      [ Ingress Controller (NGINX) ]
                                  │
                  ┌───────────────┴────────────────┐
                  │ (NetworkPolicy: Allow Ingress) │
                  ▼                                ▼
      [ Pod: Quarkus Frontend ]      [ Pod: Quarkus Backend ]
         (NS: production)               (NS: production)
                  │                                │
                  └───────────────┬────────────────┘
                                  │ (mTLS / NetworkPolicy: DENY All Default)
                                  ▼
                     [ API Server / Database ]
```

#### Paso 1: Configuración de Ingress Controller y terminación TLS/SSL

Desplegaremos el Ingress Controller de NGINX y configuraremos la terminación TLS/SSL para el dominio `checkout.local` mediante certificados digitales.

1. **Instalar el NGINX Ingress Controller vía Helm:**

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.type=ClusterIP
```

1. **Generar un certificado SSL/TLS autofirmado con OpenSSL:**

```bash
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout checkout.key -out checkout.crt \
  -subj "/CN=checkout.local/O=EcommercePlatform" \
  -addext "subjectAltName = DNS:checkout.local"
```

1. **Crear el Secret de tipo `kubernetes.io/tls` en el namespace `production`:**

```bash
kubectl create namespace production

kubectl create secret tls checkout-tls-secret \
  --key checkout.key \
  --cert checkout.crt \
  -n production
```

1. **Desplegar la carga de trabajo en Quarkus y el Ingress:**

Crea el archivo `01-ingress-quarkus.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: payment-service
  namespace: production
  labels:
    app: payment-service
spec:
  replicas: 2
  selector:
    matchLabels:
      app: payment-service
  template:
    metadata:
      labels:
        app: payment-service
    spec:
      containers:
      - name: quarkus-app
        image: quay.io/quarkus/ubi-quarkus-mandrel-builder-image:jdk-21
        command: ["sh", "-c", "echo 'Payment Service Activo' > /tmp/index.html && python3 -m http.server 8080 --directory /tmp"]
        ports:
        - containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: payment-service
  namespace: production
spec:
  type: ClusterIP
  ports:
  - port: 8080
    targetPort: 8080
    name: http
  selector:
    app: payment-service
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: checkout-ingress
  namespace: production
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - checkout.local
    secretName: checkout-tls-secret
  rules:
  - host: checkout.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: payment-service
            port:
              number: 8080
```

Aplica el manifiesto:

```bash
kubectl apply -f 01-ingress-quarkus.yaml
```

1. **Verificación de Ingress y TLS:**

Expon el Ingress Controller mediante un `port-forward` temporal en otra terminal:

```bash
kubectl port-forward svc/ingress-nginx-controller -n ingress-nginx 8443:443
```

Realiza la prueba de conectividad forzando la resolución de `checkout.local`:

```bash
curl -k -v --resolve checkout.local:8443:127.0.0.1 https://checkout.local:8443/
```

_Resultado esperado:_ Código HTTP `200 OK` con la respuesta del microservicio Quarkus y handshake SSL/TLS exitoso.

#### Paso 2: Implementación de aislamiento de red con NetworkPolicies (L3/L4)

Aplicaremos una arquitectura de red _Zero Trust_. Bloquearemos todo el tráfico por defecto dentro del _namespace_ `production` y abriremos únicamente la ruta desde el Ingress Controller hacia el microservicio Quarkus.

1. **Aplicar la política predeterminada de denegación total (Default Deny All):**

Crea el archivo `02-deny-all-networkpolicy.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: production
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
```

Aplica la regla:

```bash
kubectl apply -f 02-deny-all-networkpolicy.yaml
```

1. **Crear regla de Ingress permitida desde el Ingress Controller hacia Quarkus:**

Crea el archivo `03-allow-ingress-to-quarkus.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-ingress-to-quarkus
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: payment-service
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: ingress-nginx
      podSelector:
        matchLabels:
          app.kubernetes.io/name: ingress-nginx
    ports:
    - protocol: TCP
      port: 8080
```

Aplica la política de acceso explícito:

```bash
kubectl apply -f 03-allow-ingress-to-quarkus.yaml
```

1. **Verificación de aislamiento de red:**

Genera un _pod_ no autorizado en un _namespace_ ajeno para intentar conectarse directamente al microservicio:

```bash
kubectl run unauthorized-client --image=curlimages/curl -n default --rm -it -- restart='Never' -- \
  curl --connect-timeout 5 http://payment-service.production.svc.cluster.local:8080
```

_Resultado esperado:_ La petición falla por `Connection timed out` debido al bloqueo de la política L3/L4.

#### Paso 3: Endurecimiento de seguridad con RBAC y Pod Security Standards

Para aislar las cargas de trabajo, aplicaremos la restricción a nivel de kernel mediante el perfil _Restricted_ y vincularemos una `ServiceAccount` sin privilegios.

1. **Configurar el perfil Pod Security Standard (Restricted) en el namespace:**

```bash
kubectl label namespace production \
  pod-security.kubernetes.io/enforce=restricted \
  pod-security.kubernetes.io/enforce-version=latest \
  --overwrite
```

1. **Crear ServiceAccount y RBAC de mínimo privilegio:**

Crea el archivo `04-rbac-hardened.yaml`:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: quarkus-runtime-sa
  namespace: production
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: configmap-reader-role
  namespace: production
rules:
- apiGroups: [""]
  resources: ["configmaps"]
  verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: quarkus-config-binding
  namespace: production
subjects:
- kind: ServiceAccount
  name: quarkus-runtime-sa
  namespace: production
roleRef:
  kind: Role
  name: configmap-reader-role
  apiGroup: rbac.authorization.k8s.io
```

Aplica el control de acceso:

```bash
kubectl apply -f 04-rbac-hardened.yaml
```

1. **Re-desplegar la aplicación adaptada al estándar Restricted:**

Crea el archivo `05-hardened-quarkus-deployment.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: payment-service
  namespace: production
spec:
  replicas: 1
  selector:
    matchLabels:
      app: payment-service
  template:
    metadata:
      labels:
        app: payment-service
    spec:
      serviceAccountName: quarkus-runtime-sa
      securityContext:
        runAsNonRoot: true
        runAsUser: 10001
        runAsGroup: 10001
        fsGroup: 10001
        seccompProfile:
          type: RuntimeDefault
      containers:
      - name: quarkus-app
        image: curlimages/curl:8.5.0
        command: ["sh", "-c", "sleep 3600"]
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop:
            - ALL
```

Aplica el manifiesto endurecido:

```bash
kubectl apply -f 05-hardened-quarkus-deployment.yaml
```

1. **Verificación de permisos RBAC con `kubectl auth can-i`:**

Verifica los permisos reales de la `ServiceAccount` simulando su identidad:

```bash
# Probar permiso permitido
kubectl auth can-i list configmaps \
  --as=system:serviceaccount:production:quarkus-runtime-sa \
  -n production

# Probar permiso denegado
kubectl auth can-i delete pods \
  --as=system:serviceaccount:production:quarkus-runtime-sa \
  -n production
```

_Resultado esperado:_ La primera consulta devuelve `yes` y la segunda devuelve `no`.

#### Paso 4: Escaneo de imágenes de contenedor con Trivy

Antes de autorizar el despliegue a producción dentro del _pipeline_ CI/CD, las imágenes deben cumplir con el criterio de cero vulnerabilidades críticas (_CRITICAL_).

1. **Ejecutar el escaneo estático de vulnerabilidades sobre la imagen:**

```bash
trivy image --severity HIGH,CRITICAL curlimages/curl:8.5.0
```

1. **Simulación de fallo en pipeline por política de seguridad:**

Ejecuta el escaneo configurando un código de salida distinto de cero si se encuentran vulnerabilidades de nivel crítico:

```bash
trivy image --exit-code 1 --severity CRITICAL curlimages/curl:8.5.0
```

_Resultado esperado:_ Si la imagen tiene CVEs críticas no corregidas, el comando retorna `exit status 1`, interrumpiendo el _pipeline_ de automatización.

### 4. Guía de troubleshooting (¿qué puede fallar?)

#### Error 1: Pod bloqueado en estado `CreateContainerConfigError` o rechazo por el controlador de admisión PSS

- **Síntoma:** El _deployment_ no crea los _pods_ y el comando `kubectl get events -n production` muestra el error: `violates PodSecurity "restricted:latest"`.

- **Causa raíz:** La especificación del contenedor no cumple con el estándar _Restricted_ (ej. no declara `runAsNonRoot: true`, no incluye `seccompProfile` o mantiene la capacidad de elevación de privilegios `allowPrivilegeEscalation: true`).

- **Diagnóstico y solución:**

    1. Inspecciona los eventos exactos con `kubectl describe replicaSet -n production`.

    2. Ajusta el bloque `securityContext` del _pod_ y del _container_ verificando la eliminación de capacidades con `capabilities.drop: ["ALL"]`.

#### Error 2: El Ingress retorna código `502 Bad Gateway` o `503 Service Temporarily Unavailable`

- **Síntoma:** Al ejecutar la llamada `curl` al Ingress, el servidor NGINX responde con error `502` o `503`.

- **Causa raíz:**

    1. Las etiquetas (_labels_) definidas en el `spec.selector` del `Service` no coinciden exactamente con las etiquetas en el `template.metadata.labels` del `Deployment`.

    2. El parámetro `targetPort` del servicio no apunta al puerto real en el que escucha el proceso dentro del contenedor.

- **Diagnóstico y solución:**

    1. Verifica si el servicio tiene endpoints asignados activos:

        ```bash
        kubectl get endpoints payment-service -n production
        ```

    2. Si la lista `<none>` aparece en los endpoints, corrige la coincidencia de etiquetas (_labels_) entre el Service y el Deployment.

#### Error 3: Timeout al consumir servicios internos tras aplicar NetworkPolicies

- **Síntoma:** El microservicio no puede consultar la base de datos o el DNS interno del clúster (`CoreDNS`), congelando las llamadas.

- **Causa raíz:** Al aplicar una `NetworkPolicy` de tipo `Default Deny All` en el _namespace_, se bloquea también el tráfico de salida (_Egress_) hacia el servidor DNS del clúster (`kube-dns` en el _namespace_ `kube-system` sobre el puerto UDP/TCP 53).

- **Diagnóstico y solución:**

    1. Habilita una regla explícita de `Egress` en la política para permitir la resolución DNS:

        ```yaml
        egress:
        - to:
          - namespaceSelector: {}
          ports:
          - protocol: UDP
            port: 53
        ```

### 5. Criterios de aceptación / evidencia de entrega

Para dar por concluida y aprobada la **Práctica Integradora de la Unidad 3**, el estudiante debe entregar un reporte técnico y realizar una demostración en vivo que cumpla con las siguientes evidencias obligatorias:

#### 1. Reporte técnico de laboratorio (30%)

- Documento en formato PDF o Markdown que contenga:

  - Diagrama de arquitectura de red y seguridad del entorno desplegado.

  - Colección de manifiestos YAML utilizados (`Ingress`, `Service`, `Deployment`, `NetworkPolicy`, `Role`, `RoleBinding`, `ServiceAccount`).

  - Breve justificación técnica de cada parámetro del `securityContext` implementado.

#### 2. Demostración en vivo y verificación técnica (50%)

- **Prueba TLS/Ingress:** Ejecución exitosa del comando `curl -v https://checkout.local` demostrando la resolución de dominio y la validez del certificado TLS configurado.

- **Prueba de aislamiento L3/L4:** Demostración en tiempo real donde un _pod_ legítimo logra conectarse, mientras que un _pod_ en un _namespace_ externo falla al intentar el tráfico HTTP, comprobando la efectividad de la `NetworkPolicy`.

- **Prueba de RBAC:** Salida en terminal del comando `kubectl auth can-i` ejecutado para la `ServiceAccount` del microservicio, comprobando la aplicación del principio de mínimo privilegio (`yes` para lectura de ConfigMaps, `no` para eliminación o modificación de recursos globales).

#### 3. Lista de cotejo del proyecto integrador (20%)

| **Criterio de evaluación**                                                                                                                 | **Estado**    | **Observaciones** |
| ------------------------------------------------------------------------------------------------------------------------------------------ | ------------- | ----------------- |
| **Cero credenciales en duro:** Los manifiestos no contienen contraseñas ni llaves privadas codificadas directamente.                       | `[Pass/Fail]` |                   |
| **Estándar Restricted activo:** El _namespace_ de producción rechaza cualquier _pod_ que intente ejecutarse como `root`.                   | `[Pass/Fail]` |                   |
| **Escaneo CI/CD:** Reporte de salida de `Trivy` adjunto demostrando cero vulnerabilidades de severidad _CRITICAL_ en la imagen desplegada. | `[Pass/Fail]` |                   |
