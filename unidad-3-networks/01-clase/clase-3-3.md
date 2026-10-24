# 3.3 Seguridad en el Despliegue y Acceso

En la sesión anterior analizamos cómo asegurar la conectividad interna mediante el CNI, CoreDNS y _NetworkPolicies_, y ahora en esta sesión llevaremos ese conocimiento a la práctica al explorar RBAC, _ServiceAccounts_ y mecanismos de autenticación.

## 1. Explicación conceptual

En Kubernetes, la seguridad de acceso y despliegue opera bajo la premisa de que todo punto de acceso —ya sea un ingeniero ejecutando `kubectl` o un microservicio en Java con Quarkus consultando la API— debe ser autenticado y autorizado bajo el principio de mínimo privilegio (_Least Privilege_).

### 1.1 Control de acceso basado en roles (RBAC)

La autorización en la API del clúster se gestiona mediante cuatro objetos fundamentales:

- **`Role`:** Define un conjunto de permisos (verbos como `get`, `list`, `create`) sobre recursos específicos (`pods`, `services`) dentro de un _namespace_ delimitado.

- **`ClusterRole`:** Define permisos a nivel de todo el clúster (recursos no asociados a _namespaces_ como `nodes`, `persistentvolumes`, o recursos globales en todos los _namespaces_).

- **`RoleBinding`:** Vincula un `Role` o `ClusterRole` a un sujeto (usuario, grupo o `ServiceAccount`) restringiendo el alcance únicamente a un _namespace_ específico.

- **`ClusterRoleBinding`:** Otorga los permisos de un `ClusterRole` a un sujeto en todos los _namespaces_ del clúster.

### 1.2 Identidad para aplicaciones: serviceaccounts

Los usuarios humanos suelen autenticarse mediante proveedores OIDC o certificados X.509, pero las cargas de trabajo (_workloads_) utilizan **`ServiceAccounts`**. Cuando un _pod_ se ejecuta con una `ServiceAccount`, Kubernetes inyecta un _JSON Web Token_ (JWT) firmado de corta duración en `/var/run/secrets/kubernetes.io/serviceaccount/token`. Este token le permite a la aplicación realizar peticiones autenticadas contra la API Server de Kubernetes.

### 1.3 Gestión de datos sensibles e integración con Key Vaults

Los objetos **`Secret`** nativos de Kubernetes guardan datos confidenciales (contraseñas, tokens API). Sin embargo, por defecto están codificados únicamente en `Base64` y se almacenan sin encriptar en `etcd` (a menos que se active _encryption-at-rest_). En entornos de producción cloud-native, la mejor práctica consiste en externalizar el ciclo de vida de los secretos hacia un gestor dedicado (Azure Key Vault, HashiCorp Vault, AWS Secrets Manager) e integrarlos al clúster utilizando controladores como **External Secrets Operator (ESO)** o **Secrets Store CSI Driver**.

### 1.4 Seguridad de la carga de trabajo y cadena de suministro

- **Pod Security Standards (PSS) & Admission Controllers:** Reemplazaron a las antiguas _PodSecurityPolicies_. PSS categoriza el endurecimiento de los contenedores en tres niveles: _Privileged_ (sin restricciones), _Baseline_ (previene escalación de privilegios conocida) y _Restricted_ (exige ejecución como usuario no-root, aislamiento del sistema de archivos de solo lectura y deshabilitación de capacidades del Kernel).

- **Escaneo y firma de imágenes:** La seguridad de la cadena de suministro (_supply chain_) exige que toda imagen en el _registry_ sea escaneada contra vulnerabilidades conocidas (CVEs) antes del despliegue y validada mediante firmas digitales usando herramientas como **Cosign** / **Sigstore** a través de un _validating admission webhook_ (ej. Kyverno u OPA/Gatekeeper).

---

## 2. Analogía del mundo real

Imagina la seguridad de un hotel de alta gama:

- **ServiceAccount (La credencial del personal):** Es el gafete con chip que se le entrega a un empleado. La credencial no dice quién es la persona individualmente, sino el rol que cumple durante su turno de trabajo.

- **RBAC (Los permisos del chip):**

  - Un **`Role`** especifica qué puertas abre la tarjeta dentro del piso 3 (_namespace_): la puerta de limpieza y el cuarto de blancos.

  - Un **`RoleBinding`** es el acto de programar la tarjeta del empleado para que funcione específicamente en ese piso 3.

  - Un **`ClusterRoleBinding`** sería entregarle la llave maestra al gerente general para abrir cualquier habitación de cualquier piso de la cadena hotelera.

- **Secrets vs. Key Vaults (La caja fuerte de la habitación vs. el banco):** Dejar un `Secret` codificado en Base64 es como guardar el pasaporte en un cajón con un papel transparente encima: cualquiera que abra el cajón puede leerlo inmediatamente. Usar un _Key Vault_ externo equivale a dejar los valores de gran importancia en la bóveda de un banco y traer al hotel un duplicado temporal mediante un mensajero blindado solo cuando sea estrictamente necesario.

- **Pod Security Standards (Las reglas de protección civil):** Son los inspectores en la puerta del hotel. El nivel _Restricted_ no permite que ningún visitante entre con materiales inflamables, herramientas pesadas o sin identificación verificable, asegurando que nadie pueda tomar el control del inmueble si entra a una habitación.

---

## 3. Arquitectura de Seguridad Multinivel

```
┌─────────────────────────────────────────────────────────────┐
│ Kubernetes Cluster (kube-apiserver)                         │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌──────────────────────────────────────────────────────┐   │
│  │ Namespace: apps                                      │   │
│  │ PSS Enforce: Restricted (no root, read-only fs)     │   │
│  ├──────────────────────────────────────────────────────┤   │
│  │                                                       │   │
│  │  ┌────────────────────────────────────────────────┐  │   │
│  │  │ Deployment (payment-service)                   │  │   │
│  │  │ ├─ ServiceAccount: payment-app                 │  │   │
│  │  │ ├─ SecurityContext: runAsNonRoot: true         │  │   │
│  │  │ └─ Container: readOnlyRootFilesystem: true     │  │   │
│  │  │                                                 │  │   │
│  │  │ Pod ───→ (injected JWT token)                  │  │   │
│  │  │           ├─ Path: /var/run/secrets/.../token  │  │   │
│  │  │           └─ Issuer: kube-apiserver            │  │   │
│  │  └────────────────────────────────────────────────┘  │   │
│  │           │ ↓ (authenticated request)                │   │
│  │           │ kubectl get pods --token=<JWT>         │   │
│  │           ▼                                         │   │
│  │  ┌────────────────────────────────────────────────┐  │   │
│  │  │ RBAC RoleBinding                                │  │   │
│  │  │ ├─ ServiceAccount: payment-app                 │  │   │
│  │  │ ├─ Role: payment-app-reader                    │  │   │
│  │  │ └─ Verbs: get, list (pods only)               │  │   │
│  │  └────────────────────────────────────────────────┘  │   │
│  │           │ ↓ (authorization check)                 │   │
│  │           │ ✅ Permitido: get pods                 │   │
│  │           │ ❌ Bloqueado: delete pods              │   │
│  │           ▼                                         │   │
│  │  ┌────────────────────────────────────────────────┐  │   │
│  │  │ kube-apiserver Response: 200 OK                │  │   │
│  │  │ {"items": [...pods en namespace apps...]}      │  │   │
│  │  └────────────────────────────────────────────────┘  │   │
│  │                                                       │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                               │
└─────────────────────────────────────────────────────────────┘
```

**Flujo de seguridad por capas:**

1. **Capas de Autenticación (¿Quién eres?):**
   - Usuario: OIDC / Certificado X.509
   - Pod: ServiceAccount JWT (inyectado automáticamente)

2. **Capa de Autorización (¿Qué puedes hacer?):**
   - RBAC evalúa Role + RoleBinding
   - Respuesta: Permitido / Denegado

3. **Capa de Admisión (¿Puedes entrar con eso?):**
   - Pod Security Standards valida el manifiesto
   - Respuesta: Acepta / Rechaza antes de desplegar

4. **Capa de Aislamiento (¿Dónde puedes estar?):**
   - SecurityContext aísla el contenedor (user, filesystem, capabilities)
   - NetworkPolicy aísla la comunicación entre pods

---

## 4. RBAC: Verbos Comunes y Ejemplos

| Verbo | Típicamente Se Usa Para |
|-------|------------------------|
| `get` | Obtener un recurso específico (`pod`, `service`) |
| `list` | Listar todos los recursos en un namespace |
| `watch` | Monitorear cambios en tiempo real |
| `create` | Crear nuevos recursos |
| `update` | Modificar recursos existentes |
| `patch` | Cambios incrementales en recursos |
| `delete` | Eliminar recursos |
| `deletecollection` | Eliminar múltiples recursos |
| `exec` | Ejecutar comandos dentro de un pod |
| `logs` | Ver logs de un pod |
| `portforward` | Túnel local a puertos de pods |
| `port-forward` | Alias de `portforward` |

**Ejemplo de política restrictiva:**

```yaml
# Role: Solo lectura de pods
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-reader
  namespace: apps
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "watch"]
```

---

## 5. Pod Security Standards: Tres Niveles

| Nivel | Restricciones | Caso de Uso |
|-------|--------------|-----------|
| **Privileged** | Sin restricciones. Permite todo (root, privilegios, etc.) | Solo para contenedores de infraestructura (kubelet, CNI) |
| **Baseline** | Previene escalación de privilegios conocida | Desarrollo, aplicaciones heredadas que necesitan permisos básicos |
| **Restricted** | Máximo endurecimiento (no root, read-only fs, sin capabilities) | Producción, aplicaciones cloud-native modernas |

**Enforcing Restricted en un namespace:**

```yaml
apiVersion: v1
kind: Namespace
metadata:
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/enforce-version: latest
```

Si intentas desplegar un pod que viola estas restricciones, Kubernetes rechaza la solicitud con un error 403.

---

## 6. Cadena de Suministro: Escaneo e Integridad de Imágenes

En producción, **nunca** uses `latest` o tags sin verificar vulnerabilidades:

```
1. Desarrollador: Construye imagen y sube a registry
                         │
                         ▼
2. Scanner (Trivy/Grype): Escanea CVEs automáticamente
                         │
                         ├─ ✅ Vulnerabilidades menores → Aprobada
                         └─ 🔴 Vulnerabilidades críticas → Rechazada
                         │
                         ▼
3. Cosign/Sigstore: Firma digitalmente la imagen con clave privada
                         │
                         ▼
4. Validating Webhook (Kyverno/OPA): Antes de desplegar,
   verifica la firma digital de la imagen
                         │
                         ├─ ✅ Firma válida → Aprobada
                         └─ 🔴 Firma inválida/faltante → Rechazada
                         │
                         ▼
5. Pod se despliega en el cluster
```

---

## 7. Laboratorio

Para completar esta parte, sigue el [Laboratorio de la clase 3.3](../02-laboratorio/laboratorio-clase-3-3.md). Allí encontrarás todos los pasos, código y procedimientos necesarios para configurar Pod Security Standards, crear ServiceAccounts con permisos mínimos, implementar RBAC, validar SecurityContext y realizar escaneo de imágenes.

---

## 8. Reto de ingeniería o pregunta de reflexión

**El escenario:**

Tu empresa está migrando de un modelo monolítico a microservicios en Kubernetes. El equipo de seguridad exige que:

1. Ningún pod pueda ejecutarse como root
2. Ningún pod pueda acceder a más datos que los estrictamente necesarios
3. Ningún pod pueda comunicarse con ningún otro sin permiso explícito

Para cumplir esto, implementaste:
- Pod Security Standards en nivel `Restricted`
- RBAC con Roles mínimos por microservicio
- NetworkPolicy con Default Deny All

**Sin embargo**, los desarrolladores reportan:

- *"Mi app Java con Quarkus no inicia porque falla en escribir logs"* (readOnlyRootFilesystem)
- *"No puedo ver los logs del clúster desde la app"* (RBAC restrictivo)
- *"La app no puede hablar a la BD"* (NetworkPolicy demasiado restrictiva)

**Para debatir en clase:**

1. Propón un modelo de "Progressive Security" donde la seguridad sea restrictiva pero práctica. ¿Cómo balancearías entre máxima seguridad (teórica) vs. aplicaciones que realmente necesitan funcionar?

2. Diseña una estrategia de onboarding para desarrolladores nuevos: ¿Cómo les enseñarías que escriban código cloud-native sin que vayan contra el RBAC y NetworkPolicy?

3. Si un desarrollador dice *"En desarrollo todo debe funcionar sin restricciones"* pero luego despliega ese código en producción, ¿qué controles en el pipeline CI/CD implementarías para evitar sorpresas?
