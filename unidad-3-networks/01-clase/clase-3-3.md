# 3.3 Seguridad en el Despliegue y Acceso

En la sesión anterior analizamos cómo asegurar la conectividad interna mediante el CNI, CoreDNS y _NetworkPolicies_, y ahora en esta sesión llevaremos ese conocimiento a la práctica al explorar RBAC, _ServiceAccounts_ y mecanismos de autenticación.

## 1. Explicación conceptual

En Kubernetes, la seguridad de acceso y despliegue opera bajo la premisa de que todo punto de acceso —ya sea un operador ejecutando `kubectl` o una carga que necesita consultar la API— debe autenticarse y autorizarse con el principio de mínimo privilegio (_Least Privilege_).

### 1.1 Control de acceso basado en roles (RBAC)

La autorización en la API del clúster se gestiona mediante cuatro objetos fundamentales:

- **`Role`:** Define un conjunto de permisos (verbos como `get`, `list`, `create`) sobre recursos específicos (`pods`, `services`) dentro de un _namespace_ delimitado.

- **`ClusterRole`:** Define un conjunto de permisos reutilizable para recursos con o sin _namespace_. El alcance efectivo depende del vínculo: un `RoleBinding` puede otorgarlo en un solo _namespace_; un `ClusterRoleBinding` puede otorgarlo en todo el clúster.

- **`RoleBinding`:** Vincula un `Role` o `ClusterRole` a un sujeto (usuario, grupo o `ServiceAccount`) restringiendo el alcance únicamente a un _namespace_ específico.

- **`ClusterRoleBinding`:** Otorga los permisos de un `ClusterRole` a un sujeto en todos los _namespaces_ del clúster.

### 1.2 Identidad para aplicaciones: serviceaccounts

Los usuarios humanos suelen autenticarse mediante proveedores OIDC o certificados X.509, mientras que las cargas de trabajo pueden identificarse con **`ServiceAccounts`**. De forma predeterminada, Kubernetes proyecta en el Pod un token obtenido mediante la API `TokenRequest`; es de duración limitada y el kubelet lo rota. La aplicación puede usarlo para autenticarse ante el API Server, pero la identidad no concede permisos por sí sola: la autorización depende de RBAC y no todos los Pods necesitan un token. Se puede desactivar su montaje automático con `automountServiceAccountToken: false`.

### 1.3 Gestión de datos sensibles e integración con Key Vaults

Los objetos **`Secret`** nativos de Kubernetes guardan datos confidenciales (contraseñas, tokens API). Sus valores se representan en Base64, que no es cifrado; por defecto se almacenan sin cifrar en `etcd`, salvo que se configure _encryption at rest_. En producción, valora un gestor de secretos externo y define cómo llegan los datos a las cargas: External Secrets Operator suele sincronizarlos a objetos `Secret` de Kubernetes, mientras Secrets Store CSI Driver puede montarlos desde un proveedor externo en volúmenes.

### 1.4 Seguridad de la carga de trabajo y cadena de suministro

- **Pod Security Standards (PSS) y Pod Security Admission (PSA):** PSS define tres perfiles acumulativos: _Privileged_, _Baseline_ y _Restricted_. PSA es el mecanismo integrado de admisión que aplica esos perfiles mediante modos como `enforce`, `audit` y `warn`. `Restricted` exige, entre otros controles, ejecución no-root, `allowPrivilegeEscalation: false`, `seccompProfile` permitido y eliminar todas las capabilities (solo permite agregar `NET_BIND_SERVICE` como excepción). Un filesystem raíz de solo lectura es una medida de endurecimiento útil, pero **no** es requisito de PSS `Restricted`.

- **Escaneo y firma de imágenes:** Una política de cadena de suministro puede escanear imágenes frente a vulnerabilidades conocidas y requerir firmas verificables antes del despliegue. Cosign/Sigstore genera y verifica firmas; para hacer cumplir una política en admisión se necesita un controlador y una política configurados (por ejemplo, Kyverno o Gatekeeper).

---

## 2. Analogía del mundo real

Imagina la seguridad de un hotel de alta gama:

- **ServiceAccount (La identidad de una carga):** Es una credencial de servicio asignada a un proceso. Identifica al sujeto; los permisos que tiene se definen por separado mediante RBAC.

- **RBAC (Los permisos del chip):**

  - Un **`Role`** especifica qué puertas abre la tarjeta dentro del piso 3 (_namespace_): la puerta de limpieza y el cuarto de blancos.

  - Un **`RoleBinding`** es el acto de programar la tarjeta del empleado para que funcione específicamente en ese piso 3.

  - Un **`ClusterRoleBinding`** sería entregarle la llave maestra al gerente general para abrir cualquier habitación de cualquier piso de la cadena hotelera.

- **Secrets vs. Key Vaults (La caja fuerte de la habitación vs. el banco):** Dejar un `Secret` codificado en Base64 es como guardar el pasaporte en un cajón con un papel transparente encima: cualquiera que abra el cajón puede leerlo inmediatamente. Usar un _Key Vault_ externo equivale a dejar los valores de gran importancia en la bóveda de un banco y traer al hotel un duplicado temporal mediante un mensajero blindado solo cuando sea estrictamente necesario.

- **Pod Security Standards (Las reglas de protección civil):** Son los inspectores en la puerta del hotel. El nivel _Restricted_ no permite que ningún visitante entre con materiales inflamables, herramientas pesadas o sin identificación verificable, asegurando que nadie pueda tomar el control del inmueble si entra a una habitación.

---

## 3. Arquitectura de Seguridad Multinivel

El diagrama es un ejemplo de una carga que sí consulta el API Server; no todas las aplicaciones necesitan token ni permisos de API.

```
┌─────────────────────────────────────────────────────────────┐
│ Kubernetes Cluster (kube-apiserver)                         │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌──────────────────────────────────────────────────────┐   │
│  │ Namespace: apps                                      │   │
│  │ PSA Enforce: Restricted                             │   │
│  ├──────────────────────────────────────────────────────┤   │
│  │                                                       │   │
│  │  ┌────────────────────────────────────────────────┐  │   │
│  │  │ Deployment (payment-service)                   │  │   │
│  │  │ ├─ ServiceAccount: payment-app                 │  │   │
│  │  │ ├─ SecurityContext: runAsNonRoot: true         │  │   │
│  │  │ └─ Container: readOnlyRootFilesystem: true     │  │   │
│  │  │                                                 │  │   │
│  │  │ Pod ───→ (projected, rotating token, optional) │  │   │
│  │  │           └─ TokenRequest API                  │  │   │
│  │  └────────────────────────────────────────────────┘  │   │
│  │           │ ↓ (authenticated request)                │   │
│  │           │ request authenticated as ServiceAccount│   │
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
│  │  │ API server response: allowed/forbidden         │  │   │
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
   - Pod: token proyectado de ServiceAccount (si está habilitado)

2. **Capa de Autorización (¿Qué puedes hacer?):**
   - RBAC evalúa Role + RoleBinding
   - Respuesta: Permitido / Denegado

3. **Capa de Admisión (¿Cumple la política de Pods?):**
   - Pod Security Admission evalúa el Pod según el perfil y modo del namespace
   - Respuesta: admite, advierte, audita o rechaza según el modo

4. **Capa de endurecimiento y conectividad:**
   - `SecurityContext` configura atributos de seguridad del proceso y el contenedor (usuario, filesystem y capabilities)
   - `NetworkPolicy` controla flujos de red entre Pods, si el CNI implementa las políticas

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

`exec`, `logs` y `port-forward` no son verbos RBAC. Se autorizan como subrecursos: por ejemplo, `pods/exec` y `pods/portforward` suelen requerir `create`; `pods/log` suele requerir `get`. El verbo exacto depende de la operación HTTP que haga el cliente.

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
| **Privileged** | Sin restricciones. Permite todo (root, privilegios, etc.) | Solo para Pods de infraestructura que realmente requieran esas capacidades, como algunos componentes CNI |
| **Baseline** | Previene escalación de privilegios conocida | Desarrollo, aplicaciones heredadas que necesitan permisos básicos |
| **Restricted** | Endurecimiento fuerte; requiere, entre otros, no-root, `allowPrivilegeEscalation: false`, seccomp permitido y `drop: ["ALL"]`. No exige filesystem raíz de solo lectura. | Workloads que pueden cumplir el perfil |

**Enforcing Restricted en un namespace:**

```yaml
apiVersion: v1
kind: Namespace
metadata:
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/enforce-version: latest
```

Si el namespace usa modo `enforce` y el Pod incumple el perfil, la admisión lo rechaza. Antes de activar `enforce` en un namespace existente, revisa todos sus workloads, ya que las nuevas creaciones y actualizaciones de Pods también se evaluarán.

---

## 6. Cadena de Suministro: Escaneo e Integridad de Imágenes

En producción, evita tags mutables como `latest`; fija imágenes por digest o usa tags inmutables y aplica un proceso de análisis y validación:

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

Para completar esta parte, sigue el [Laboratorio de la clase 3.3](../02-laboratorio/laboratorio-clase-3-3.md). Allí configurarás Pod Security Admission, aplicarás una ServiceAccount sin token innecesario, comprobarás permisos RBAC y actualizarás el Deployment mediante RollingUpdate.

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

## Fuentes primarias

- Kubernetes Authors. _Pod Security Standards_. <https://kubernetes.io/docs/concepts/security/pod-security-standards/>
- Kubernetes Authors. _Pod Security Admission_. <https://kubernetes.io/docs/concepts/security/pod-security-admission/>
- Kubernetes Authors. _Service Accounts_. <https://kubernetes.io/docs/concepts/security/service-accounts/>
- Kubernetes Authors. _RBAC Authorization_. <https://kubernetes.io/docs/reference/access-authn-authz/rbac/>
- Kubernetes Authors. _RBAC good practices_. <https://kubernetes.io/docs/concepts/security/rbac-good-practices/>
- Kubernetes Authors. _Good practices for Kubernetes Secrets_. <https://kubernetes.io/docs/concepts/security/secrets-good-practices/>
