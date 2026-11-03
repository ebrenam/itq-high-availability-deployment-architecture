# 3.3 Seguridad en el despliegue y acceso

En la sesión anterior analizamos cómo asegurar la conectividad interna mediante el CNI, CoreDNS y _NetworkPolicies_, y ahora en esta sesión llevaremos ese conocimiento a la práctica al explorar RBAC, _ServiceAccounts_ y mecanismos de autenticación.

## 1. Explicación conceptual

En Kubernetes, la seguridad de acceso y despliegue opera bajo la premisa de que todo punto de acceso —ya sea un operador ejecutando `kubectl` o una carga que necesita consultar la API— debe autenticarse y autorizarse con el principio de mínimo privilegio (_Least Privilege_).

### 1.1 Control de acceso basado en roles (RBAC)

La autorización en la API del clúster se gestiona mediante cuatro objetos fundamentales:

- **`Role`:** Define un conjunto de permisos (verbos como `get`, `list`, `create`) sobre recursos específicos (`pods`, `services`) dentro de un _namespace_ delimitado.

- **`ClusterRole`:** Define un conjunto de permisos reutilizable para recursos con o sin _namespace_. El alcance efectivo depende del vínculo: un `RoleBinding` puede otorgarlo en un solo _namespace_; un `ClusterRoleBinding` puede otorgarlo en todo el clúster.

- **`RoleBinding`:** Vincula un `Role` o `ClusterRole` a un sujeto (usuario, grupo o `ServiceAccount`) restringiendo el alcance únicamente a un _namespace_ específico.

- **`ClusterRoleBinding`:** Otorga los permisos de un `ClusterRole` a un sujeto en todos los _namespaces_ del clúster.

### 1.2 Identidad para aplicaciones: ServiceAccounts

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

## 3. Arquitectura de eguridad multinivel

Kubernetes implementa **4 capas de seguridad independientes** que se aplican en secuencia. Cada capa es un "checkpoint" que debe pasar para que una solicitud tenga éxito.

### El viaje de una solicitud: Desde el Pod al API Server

Imaginemos que tu aplicación dentro del Pod payment-service quiere listar otros Pods:

```
PASO 1: ENDURECIMIENTO LOCAL (SecurityContext)
═══════════════════════════════════════════════
Pod intenta ejecutar comando:
  /app > java -jar payment-service.jar
  
✅ SecurityContext valida:
   - ¿Puedo ejecutar como usuario no-root (uid: 1000)?
   - ¿Es mi filesystem read-only (excepto /tmp)?
   - ✅ Sí → Continuar
   - ❌ No → Pod no inicia (CrashLoopBackOff)

│
▼

PASO 2: AUTENTICACIÓN (¿Quién eres?)
═════════════════════════════════════
App dentro del Pod intenta: kubectl get pods
  
✅ Kubelet proporciona token del ServiceAccount:
   ServiceAccount: "payment-app"
   Token: (jwt firmado por control plane)
   
✅ API Server valida la firma:
   - ¿Quién eres? → ServiceAccount: payment-app
   - ✅ Válido → Continuar
   - ❌ Inválido/expirado → Rechazar (HTTP 401)

│
▼

PASO 3: AUTORIZACIÓN (¿Qué puedes hacer?)
═══════════════════════════════════════════
API Server evalúa RBAC:
  
✅ Busca RoleBinding que vincule payment-app:
   Role: payment-app-reader
   Verbs: [get, list]
   Resources: [pods]
   
✅ Consulta:
   - ¿Permite payment-app hacer get/list de pods? → Sí
   - ✅ Permitido → Continuar
   - ❌ Rechazado (HTTP 403)

│
▼

PASO 4: ADMISIÓN (¿Cumple políticas del cluster?)
═══════════════════════════════════════════════════
Cuando **nuevo Pod es creado**, Pod Security Admission valida:
  
✅ Chequea pod-security.kubernetes.io/enforce: restricted
   - ¿runAsNonRoot: true? ✅
   - ¿allowPrivilegeEscalation: false? ✅
   - ¿seccomp válido? ✅
   - ¿capabilities [ALL] eliminada? ✅
   - ✅ Cumple → Pod creado
   - ❌ Incumple → Rechazar (admission webhook)

│
▼

PASO 5: RED (NetworkPolicy)
════════════════════════════
Cuando payment-service intenta conectar a inventory-service:
  
✅ CNI evalúa NetworkPolicy:
   - ¿Hay política Default Deny? ✅ Sí → Revisar Egress
   - ¿Permite payment-service → inventory-service? ✅ Sí
   - ✅ Tráfico permitido
   - ❌ Tráfico bloqueado por CNI (sin respuesta)

│
▼

✅ SOLICITUD PERMITIDA → App puede listar Pods
```

### Resumen: Las 4 Capas de seguridad

| Capa | Pregunta | Componente | Acción Si Falla |
|------|----------|-----------|-----------------|
| **1. Endurecimiento Local** | ¿Puedo ejecutar con estas restricciones? | `SecurityContext` | Pod no inicia |
| **2. Autenticación** | ¿Quién eres realmente? | ServiceAccount + Token | HTTP 401 (Unauthorized) |
| **3. Autorización** | ¿Tienes permiso para esto? | RBAC (Role + RoleBinding) | HTTP 403 (Forbidden) |
| **4. Admisión** | ¿Tu Pod cumple políticas del cluster? | Pod Security Admission | Pod rechazado |
| **5. Red** | ¿Puedes comunicarte con otros Pods? | NetworkPolicy + CNI | Tráfico bloqueado silenciosamente |

### Puntos Clave

- **Todas las capas son independientes:** Un Pod puede fallar en admisión pero pasar autenticación
- **Default allow:** Si no hay política configurada en una capa, se permite (excepto en admisión con `enforce`)
- **No todas las apps necesitan cada capa:** Una app que no consulta API Server no necesita token ni RBAC
- **Failures are explicit o silenciosos:** RBAC falla con HTTP 403 (visible); NetworkPolicy falla en silencio (solo logs del CNI)

---

## 4. RBAC: Verbos comunes y ejemplos

RBAC es el mecanismo de Kubernetes para definir "quién puede hacer qué". Un `Role` define acciones permitidas (verbos) sobre recursos específicos; un `RoleBinding` vincula ese `Role` a un `ServiceAccount`. Si un Pod intenta una acción no permitida, el API Server responde con HTTP 403 (Forbidden). La regla fundamental: asigna solo los verbos mínimos que la aplicación realmente necesita.

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

## 5. Pod Security Standards: Tres niveles

Pod Security Standards (PSS) define tres perfiles que puedes aplicar a un namespace: `Privileged` (sin restricciones), `Baseline` (previene escalación de privilegios obvia) y `Restricted` (endurecimiento fuerte). Kubernetes valida automáticamente cada nuevo Pod contra el perfil elegido mediante etiquetas en el namespace. Sin PSS, un desarrollador podría desplegar un Pod ejecutando como root con acceso total al filesystem, sin que haya validación automática.

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

## 6. Cadena de suministro: Escaneo e integridad de imágenes

Cuando despliegas una imagen Docker en Kubernetes, no sabes automáticamente si contiene vulnerabilidades conocidas o si fue modificada maliciosamente. Una cadena de suministro segura valida la imagen ANTES de permitir el despliegue mediante escaneo de CVEs (Trivy, Grype) y firma digital (Cosign/Sigstore). Una imagen comprometida en producción pone en riesgo todo el cluster.

En producción, **nunca uses tags mutables** como `latest`. Especifica versiones exactas (`v1.2.3`) o digests SHA256 (`sha256:abc123...`). Esto asegura reproducibilidad: hoy despliegas la misma imagen que hace un año.

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
