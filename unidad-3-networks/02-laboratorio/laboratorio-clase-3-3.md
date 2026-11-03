# Laboratorio de la clase 3.3: Endurecimiento con RBAC, SecurityContext y Pod Security Admission

## Objetivo del laboratorio y escenario real

**El escenario:** Completaste Labs 3.1 y 3.2 con payment-service desplegado y aislado con NetworkPolicy. Sin embargo, los Pods todavía:
- Corren como root (usuario 0)
- Pueden usar privilegios escalados
- Tienen acceso completo al filesystem
- Usan tokens de API Server de Kubernetes sin restricción

Ahora necesitas:
1. Crear identidad de aplicación (ServiceAccount + RBAC)
2. Endurecer Pods con SecurityContext (no-root, read-only FS)
3. Aplicar Pod Security Admission (PSA) con perfil `Restricted`
4. Validar que todo sigue funcionando con estas restricciones

**El objetivo:** Implementar defensa en profundidad: NetworkPolicy (red) + RBAC (identidad/autorización) + SecurityContext (hardening) + PSA (validación).

**Salida esperada:** payment-service ejecutándose como usuario no-privilegiado (1000), sin acceso a escribir en filesystem, con permisos RBAC mínimos, y el namespace enforcing Pod Security Restricted.

---

## Requisitos previos

- Laboratorio 3.2 **completamente terminado** (NetworkPolicy aplicadas y validadas)
- payment-service en v1.0.0 ejecutándose con 2 replicas en namespace `production`
- Gateway API y Envoy Gateway funcionales y accesibles
- Permisos administrativos en el clúster (crear Roles, RoleBindings, etiquetas de namespace)
- `kubectl` compatible con Kubernetes 1.28+
- Imagen de payment-service publicada en Docker Hub (v1.0.0)

**Nota pedagógica:** Este laboratorio modifica el Deployment existente mediante patches, no lo elimina. Así se mantiene la continuidad de servicio.

---

## Notas pedagógicas previas

**Qué aprenderás:**
- Diferencia entre ServiceAccount (identidad) y Role/RoleBinding (autorización)
- SecurityContext: `runAsNonRoot`, `runAsUser`, `readOnlyRootFilesystem`, `capabilities`
- Pod Security Standards (PSS): `Restricted`, `baseline`, `unrestricted`
- Pod Security Admission (PSA): cómo validar automáticamente Pods contra PSS
- Por qué `automountServiceAccountToken: false` cuando la app no usa API

**Por qué es importante:**
- Un compromiso en el Pod tiene menos poder si corre no-root
- No puede escribir en filesystem → limita daño de malware
- Permisos RBAC explícitos previenen escalación de privilegios
- PSA previene regresión: nuevos Pods deben cumplir estándares

---

## Pasos del laboratorio

### Paso 1: Revisar Deployment actual de payment-service

**Qué hace:** Inspecciona el Deployment antes de modificarlo.

**Por qué:** Necesitas entender cómo cambiará para validar después.

![linux](images/linux.png) **Linux/macOS:**

```bash
cd proyecto-base-unidad-03

# Ver Deployment actual
kubectl get deployment payment-service -n production -o yaml | head -50

# Ver Pods actuales
kubectl get pods -n production -l app=payment-service -o yaml | head -30

# Ver SecurityContext actual (debe ser vacío o mínimo)
kubectl get pods -n production -l app=payment-service \
  -o jsonpath='{.items[0].spec.securityContext}'

# Ver si tiene ServiceAccount
kubectl get pods -n production -l app=payment-service \
  -o jsonpath='{.items[0].spec.serviceAccountName}'
```

![win](images/windows.png) **Windows (PowerShell):**

```powershell
cd proyecto-base-unidad-03

kubectl get deployment payment-service -n production -o yaml | Select-Object -First 50

kubectl get pods -n production -l app=payment-service -o yaml | Select-Object -First 30

kubectl get pods -n production -l app=payment-service `
  -o jsonpath='{.items[0].spec.securityContext}'

kubectl get pods -n production -l app=payment-service `
  -o jsonpath='{.items[0].spec.serviceAccountName}'
```

**Qué observar:**
- Deployment existe en `production`
- Pods corren sin `securityContext` especificado (heredan default del clúster)
- `serviceAccountName` probablemente es `default` (ServiceAccount por defecto)

---

### Paso 2: Crear ServiceAccount y RBAC para payment-service

**Qué hace:** Define identidad explícita (ServiceAccount) con permisos acotados (Role/RoleBinding).

**Por qué:** Aunque la app no use API Kubernetes, es práctica establecer autorización mínima.

**Crear archivo `payment-rbac.yaml`:**

Genera el archivo con el siguiente contenido:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: payment-service-sa
  namespace: production
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: payment-service-reader
  namespace: production
rules:
  # Permiso mínimo: leer UN ConfigMap específico (para validar RBAC)
  - apiGroups: [""]
    resources: ["configmaps"]
    resourceNames: ["payment-config"]
    verbs: ["get"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: payment-service-reader-binding
  namespace: production
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: payment-service-reader
subjects:
  - kind: ServiceAccount
    name: payment-service-sa
    namespace: production
```

**Aplicar:**

```bash
kubectl apply -f payment-rbac.yaml

kubectl get serviceaccount,role,rolebinding -n production | grep payment
```

**Qué observar:**
- ServiceAccount `payment-service-sa` creada
- Role `payment-service-reader` con permiso mínimo (solo `get` en `payment-config`)
- RoleBinding vincula la ServiceAccount al Role

**Nota pedagógica:** El Role es MÁS restrictivo que "denegar todo" porque:
- Permite SOLO `get` (no `list`, `delete`, `create`)
- Permite SOLO el ConfigMap `payment-config` (no `payment-config-*` o cualquier ConfigMap)
- Cualquier otro recurso (Secrets, Pods, etc.) está denegado implícitamente

---

### Paso 3: Validar autorización con `kubectl auth can-i`

**Qué hace:** Verifica qué permisos tiene la ServiceAccount.

**Por qué:** Confirmar que RBAC está configurado correctamente.

![linux](images/linux.png) **Linux/macOS:**

```bash
# Permiso PERMITIDO: get configmaps/payment-config
kubectl auth can-i get configmaps/payment-config \
  --as=system:serviceaccount:production:payment-service-sa \
  -n production

# Esperado: yes

# Permiso DENEGADO: list configmaps
kubectl auth can-i list configmaps \
  --as=system:serviceaccount:production:payment-service-sa \
  -n production

# Esperado: no

# Permiso DENEGADO: get secrets
kubectl auth can-i get secrets \
  --as=system:serviceaccount:production:payment-service-sa \
  -n production

# Esperado: no

# Permiso DENEGADO: delete pods
kubectl auth can-i delete pods \
  --as=system:serviceaccount:production:payment-service-sa \
  -n production

# Esperado: no
```

![win](images/windows.png) **Windows (PowerShell):**

```powershell
kubectl auth can-i get configmaps/payment-config `
  --as=system:serviceaccount:production:payment-service-sa `
  -n production

kubectl auth can-i list configmaps `
  --as=system:serviceaccount:production:payment-service-sa `
  -n production

kubectl auth can-i get secrets `
  --as=system:serviceaccount:production:payment-service-sa `
  -n production

kubectl auth can-i delete pods `
  --as=system:serviceaccount:production:payment-service-sa `
  -n production
```

**Qué observar:**
- Primer comando devuelve `yes`
- Los otros tres devuelven `no`
- Esto confirma que la autorización está correctamente restringida

**Nota:** Estos comandos requieren que TÚ (el usuario administrativo) tengas permiso para impersonar (`impersonate`). Es un permiso por defecto en clusters admin.

---

### Paso 4: Aplicar SecurityContext al Deployment

**Qué hace:** Actualiza payment-service Deployment para correr no-root y con filesystem read-only.

**Por qué:** Reduce la superficie de ataque en caso de compromiso.

**Crear archivo `payment-security-patch.yaml`:**

Genera el archivo con el siguiente contenido:

```yaml
spec:
  template:
    spec:
      serviceAccountName: payment-service-sa
      automountServiceAccountToken: false
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        fsGroup: 1000
        seccompProfile:
          type: RuntimeDefault
      containers:
      - name: payment-service
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop:
            - ALL
```

**Aplicar parche:**

```bash
kubectl patch deployment payment-service -n production \
  --type=strategic \
  --patch-file=payment-security-patch.yaml

# Ver que se aplica
kubectl get deployment payment-service -n production -o yaml | grep -A 30 "securityContext:"
```

![win](images/windows.png) **Windows (PowerShell):**

```powershell
$patch = @'
spec:
  template:
    spec:
      serviceAccountName: payment-service-sa
      automountServiceAccountToken: false
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        fsGroup: 1000
        seccompProfile:
          type: RuntimeDefault
      containers:
      - name: payment-service
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop:
            - ALL
'@

$patch | Out-File -FilePath payment-security-patch.yaml -Encoding UTF8

kubectl patch deployment payment-service -n production `
  --type=strategic `
  --patch-file=payment-security-patch.yaml

kubectl get deployment payment-service -n production -o yaml | Select-String -Context 0,30 "securityContext:"
```

**Qué observar:**
- Deployment se actualiza sin errores
- Inicia RollingUpdate (los Pods se recrean uno a uno)
- Los nuevos Pods tienen `securityContext` aplicado

**Nota pedagógica:** 
- `runAsNonRoot: true` - Bloquea si intenta correr como root
- `runAsUser: 1000` - Usuario específico (no root)
- `readOnlyRootFilesystem: true` - No puede escribir en `/`, `/etc`, `/bin`, etc.
- `capabilities: drop: [ALL]` - Elimina todos los capabilities de Linux (sin `CAP_NET_BIND_SERVICE`, etc.)
- `automountServiceAccountToken: false` - No monta token (la app no lo usa)

---

### Paso 5: Esperar RollingUpdate y validar

**Qué hace:** Monitorea que los nuevos Pods inician y están listos.

**Por qué:** Asegurarse que los cambios de seguridad no rompen la aplicación.

![linux](images/linux.png) **Linux/macOS:**

```bash
# Esperar a que el rollout complete
kubectl rollout status deployment/payment-service -n production --timeout=120s

# Ver Pods nuevos (debería tener diferentes UIDs en metadata.generation)
kubectl get pods -n production -l app=payment-service -o wide

# Ver effectivamente qué usuario corre
kubectl get pods -n production -l app=payment-service \
  -o jsonpath='{range .items[*]}{.metadata.name}{" runAsUser="}{.spec.securityContext.runAsUser}{"\n"}{end}'

# Ver que está read-only
kubectl get pods -n production -l app=payment-service \
  -o jsonpath='{range .items[*]}{.metadata.name}{" readOnlyRootFilesystem="}{.spec.containers[0].securityContext.readOnlyRootFilesystem}{"\n"}{end}'
```

![win](images/windows.png) **Windows (PowerShell):**

```powershell
kubectl rollout status deployment/payment-service -n production --timeout=120s

kubectl get pods -n production -l app=payment-service -o wide

kubectl get pods -n production -l app=payment-service `
  -o jsonpath='{range .items[*]}{.metadata.name}{" runAsUser="}{.spec.securityContext.runAsUser}{"\n"}{end}'

kubectl get pods -n production -l app=payment-service `
  -o jsonpath='{range .items[*]}{.metadata.name}{" readOnlyRootFilesystem="}{.spec.containers[0].securityContext.readOnlyRootFilesystem}{"\n"}{end}'
```

**Qué observar:**
- Ambos Pods están `Running` y `Ready` (1/1)
- `runAsUser=1000` en todos ellos
- `readOnlyRootFilesystem=true` en todos ellos

---

### Paso 6: Activar Pod Security Admission en modo warn/audit

**Qué hace:** Etiqueta namespace con PSS labels para validación.

**Por qué:** Prevenir futuros Pods que no cumplan `Restricted`.

![linux](images/linux.png) **Linux/macOS:**

```bash
# Activar warn (muestra warnings en stderr) y audit (registra en audit log)
kubectl label namespace production \
  pod-security.kubernetes.io/warn=restricted \
  pod-security.kubernetes.io/warn-version=latest \
  pod-security.kubernetes.io/audit=restricted \
  pod-security.kubernetes.io/audit-version=latest \
  --overwrite

# Verificar etiquetas
kubectl get namespace production --show-labels
```

![win](images/windows.png) **Windows (PowerShell):**

```powershell
kubectl label namespace production `
  pod-security.kubernetes.io/warn=restricted `
  pod-security.kubernetes.io/warn-version=latest `
  pod-security.kubernetes.io/audit=restricted `
  pod-security.kubernetes.io/audit-version=latest `
  --overwrite

kubectl get namespace production --show-labels
```

**Qué observar:**
- Namespace etiquetado con 4 labels de PSA
- Los Pods existentes NO se ven afectados (PSA eval al admit, no a Pods existentes)

**Nota:** Todavía no activamos `enforce=restricted`. Primero validamos con `warn`.

---

### Paso 7: Intentar crear Pod incumplidor para validar warn

**Qué hace:** Crea un Pod deliberadamente incumplidor para ver si PSA lo rechaza o advierte.

**Por qué:** Confirmar que PSA está validando correctamente.

**Crear archivo `insecure-pod.yaml`:**

Genera el archivo con el siguiente contenido:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: insecure-test
  namespace: production
spec:
  serviceAccountName: default
  automountServiceAccountToken: true
  securityContext:
    runAsUser: 0  # ROOT - Viola Restricted
  containers:
  - name: test
    image: busybox:1.35
    command: ["sleep", "3600"]
```

**Intentar crear:**

```bash
kubectl apply -f insecure-pod.yaml

kubectl describe pod insecure-test -n production | head -30

kubectl delete pod insecure-test -n production
```

**Qué observar:**
- Pod se crea exitosamente (estamos en modo `warn`, no `enforce`)
- En logs o describe debería ver warning sobre "rootuser" o similar

---

### Paso 8: Activar Pod Security Admission en modo enforce

**Qué hace:** Cambia a modo enforce (rechaza Pods incumplidores).

**Por qué:** Asegurar que TODOS los Pods futuros cumplan `Restricted`.

![linux](images/linux.png) **Linux/macOS:**

```bash
# Activar enforce
kubectl label namespace production \
  pod-security.kubernetes.io/enforce=restricted \
  pod-security.kubernetes.io/enforce-version=latest \
  --overwrite

# Verificar
kubectl get namespace production --show-labels
```

![win](images/windows.png) **Windows (PowerShell):**

```powershell
kubectl label namespace production `
  pod-security.kubernetes.io/enforce=restricted `
  pod-security.kubernetes.io/enforce-version=latest `
  --overwrite

kubectl get namespace production --show-labels
```

**Qué observar:**
- Namespace etiquetado con `enforce=restricted`
- Los Pods existentes (payment-service) continúan sin ser afectados

---

### Paso 9: Intentar crear nuevo Pod incumplidor en modo enforce

**Qué hace:** Valida que PSA rechaza Pods inseguros.

**Por qué:** Confirmar que enforce está funcionando.

```bash
# Intentar crear Pod inseguro
kubectl apply -f insecure-pod.yaml

# Esperado: Error - "violates PodSecurityPolicy"
```

**Qué observar:**
- API Server rechaza el Pod con error claro
- Mensaje menciona "Pod Security" o "Restricted profile"

---

### Paso 10: Probar que payment-service sigue funcionando

**Qué hace:** Valida que con toda la seguridad aplicada, el servicio sigue activo.

**Por qué:** Confirmar que SecurityContext + PSA + RBAC no rompieron la app.

**Si todavía tienes port-forward de Lab 3.1:**

```bash
# Probar HTTPS vía Gateway
curl --cacert payment.crt \
  --resolve payment.local:8443:127.0.0.1 \
  -i https://payment.local:8443/v1/payments \
  -H "Content-Type: application/json" \
  -d '{"productId":"PROD-FINAL","quantity":1,"amount":99.99}'

# Esperado: JSON con transactionId, status, etc.
```

**Alternativa (exec en Pod):**

```bash
# Acceder a un Pod de payment-service
POD=$(kubectl get pods -n production -l app=payment-service -o jsonpath='{.items[0].metadata.name}')

# Ver logs (app debe estar sano)
kubectl logs $POD -n production | tail -20

# Health check
kubectl exec $POD -n production -- curl -s http://localhost:8080/health/live
```

![win](images/windows.png) **Windows (PowerShell):**

```powershell
$POD = kubectl get pods -n production -l app=payment-service -o jsonpath='{.items[0].metadata.name}'

kubectl logs $POD -n production | Select-Object -Last 20

kubectl exec $POD -n production -- curl -s http://localhost:8080/health/live
```

**Qué observar:**
- Respuesta HTTP 200 desde /health/live
- Curl HTTPS devuelve JSON de pago válido
- Sin errores en logs relacionados a permisos

**Nota pedagógica:** Si el Pod falla con permisos read-only, verifícalo con:
```bash
kubectl describe pod $POD -n production | grep -A 5 "Mounts:"
```

---

### Paso 11: Verificar configuración final completa

**Qué hace:** Auditoría de todos los controles aplicados.

**Por qué:** Documentar la postura de seguridad alcanzada.

```bash
# Ver Deployment con SecurityContext
kubectl get deployment payment-service -n production -o yaml | grep -A 50 "spec:"

# Ver Pods con configuración efectiva
kubectl get pods -n production -l app=payment-service -o jsonpath='{range .items[*]}{.metadata.name}{"\n  ServiceAccount: "}{.spec.serviceAccountName}{"\n  RunAsUser: "}{.spec.securityContext.runAsUser}{"\n  ReadOnly: "}{.spec.containers[0].securityContext.readOnlyRootFilesystem}{"\n"}{end}'

# Ver RBAC
kubectl get role,rolebinding -n production | grep payment

# Ver PSA labels en namespace
kubectl get namespace production -o jsonpath='{.metadata.labels}' | tr ',' '\n'
```

![win](images/windows.png) **Windows (PowerShell):**

```powershell
kubectl get deployment payment-service -n production -o yaml | Select-String -Context 0,50 "spec:"

kubectl get pods -n production -l app=payment-service -o jsonpath='{range .items[*]}{.metadata.name}{"\n  ServiceAccount: "}{.spec.serviceAccountName}{"\n  RunAsUser: "}{.spec.securityContext.runAsUser}{"\n  ReadOnly: "}{.spec.containers[0].securityContext.readOnlyRootFilesystem}{"\n"}{end}'

kubectl get role,rolebinding -n production | Select-String "payment"

kubectl get namespace production -o jsonpath='{.metadata.labels}'
```

**Qué observar:** Todos los componentes están en lugar:
- ServiceAccount: `payment-service-sa`
- RunAsUser: `1000`
- ReadOnly: `true`
- RBAC: Role + RoleBinding presentes
- PSA: Etiquetas de enforce/warn/audit visibles

---

## Troubleshooting

### Problema 1: "Pod falla al iniciar después de read-only"

**Síntomas:** `CrashLoopBackOff` en payment-service después de aplicar SecurityContext.

**Causa:** La app intenta escribir en filesystem y no puede.

**Solución:**

```bash
# Ver logs de error
kubectl logs deployment/payment-service -n production

# Si la imagen es distroless (no tiene shell), usa jq o jsonpath
# para ver qué permission denied ocurre

# Revisar si hay emptyDir para temp storage
kubectl describe pod <payment-pod> -n production | grep -A 5 "Mounts:"

# Si necesita /tmp, agregarlo en el Deployment:
# spec:
#   template:
#     spec:
#       volumes:
#       - name: tmp
#         emptyDir: {}
#       containers:
#       - volumeMounts:
#         - name: tmp
#           mountPath: /tmp
```

---

### Problema 2: "kubectl auth can-i falla"

**Síntomas:** Comando retorna error en lugar de `yes` o `no`.

**Causa:** Usuario actual (tú) no tiene permiso para impersonar.

**Solución:**

```bash
# Verificar tu acceso
kubectl auth can-i create roles -n production

# Si tienes acceso admin, deberías poder impersonar
# Si no, contacta al admin del clúster
```

---

### Problema 3: "PSA reject pod pero no veo mensaje claro"

**Síntomas:** `kubectl apply` falla sin mensaje útil.

**Solución:**

```bash
# Ver evento completo
kubectl describe namespace production

# Ver audit log (si está habilitado)
# Ubicación típica: /var/log/pods/kube-apiserver-*/kube-apiserver*.log

# Aplicar con verbose
kubectl apply -f insecure-pod.yaml -v=10
```

---

## Evidencia y Reflexión

**Documentar:**

1. **RBAC:**
   ```bash
   kubectl get serviceaccount,role,rolebinding -n production
   kubectl auth can-i get configmaps/payment-config --as=system:serviceaccount:production:payment-service-sa -n production
   ```

2. **SecurityContext:**
   ```bash
   kubectl get pods -n production -l app=payment-service -o jsonpath='{.items[0].spec.securityContext}'
   kubectl get pods -n production -l app=payment-service -o jsonpath='{.items[0].spec.containers[0].securityContext}'
   ```

3. **PSA Labels:**
   ```bash
   kubectl get namespace production --show-labels
   ```

4. **Servicio Funcional:**
   ```bash
   curl --cacert payment.crt https://payment.local:8443/v1/payments
   kubectl logs deployment/payment-service -n production | tail -5
   ```

**Preguntas de reflexión:**

1. **¿Qué diferencia hay entre `runAsNonRoot: true` y `runAsUser: 1000`?**
   - Respuesta: `runAsNonRoot` bloquea si la imagen intenta correr como root (uid 0). `runAsUser: 1000` fuerza el usuario específico. Juntas, aseguran no-root E UID consistente.

2. **¿Por qué `readOnlyRootFilesystem: true` es importante?**
   - Respuesta: Previene que malware escriba ejecutables o modifique configuración. Si la app necesita escribir, debe usar `emptyDir` o PersistentVolume.

3. **¿Por qué crear un Role si la app no accede a la API?**
   - Respuesta: Defensa en profundidad. Si la app es comprometida y intenta leer Secrets o escalar privlegios, no puede. Es mucho más restrictivo que "denegar todo por defecto".

4. **¿Cuál es la diferencia entre PSA `warn` y `enforce`?**
   - Respuesta: `warn` muestra advertencias sin rechazar. `enforce` rechaza Pods que no cumplan. Comenzamos con `warn` para auditar; luego escalamos a `enforce`.

5. **¿Qué sucede si aplicas `enforce=restricted` a un namespace donde ya hay Pods inseguros?**
   - Respuesta: Los Pods existentes NO se ven afectados (PSA eval al admit, no retroactivamente). Nuevos Pods sí serían rechazados.

---

## Continuidad y Reflexión Final

**Has completado 3 capas de seguridad:**
1. **Lab 3.1**: Gateway API con TLS (acceso controlado externamente)
2. **Lab 3.2**: NetworkPolicy (aislamiento L3/L4 entre Pods)
3. **Lab 3.3**: RBAC + SecurityContext + PSA (endurecimiento del Pod mismo)

Ninguna capa por sí sola es suficiente. Juntas forman defensa en profundidad real.

**Siguiente paso en una carrera real:** Service Mesh (Istio, Linkerd) para observabilidad + mTLS automático.

---

## Fuentes primarias

- Kubernetes Docs: Security Context
  - <https://kubernetes.io/docs/tasks/configure-pod-container/security-context/>
  
- Kubernetes Docs: Pod Security Standards
  - <https://kubernetes.io/docs/concepts/security/pod-security-standards/>
  
- Kubernetes Docs: Pod Security Admission
  - <https://kubernetes.io/docs/concepts/security/pod-security-admission/>
  
- Kubernetes Docs: RBAC Authorization
  - <https://kubernetes.io/docs/reference/access-authn-authz/rbac/>
  
- Kubernetes Docs: Service Accounts
  - <https://kubernetes.io/docs/concepts/security/service-accounts/>
  
- OWASP: Container Security Cheat Sheet
  - <https://cheatsheetseries.owasp.org/cheatsheets/Container_Security_Cheat_Sheet.html>

---

**Laboratorio completado cuando:** 
- payment-service ejecuta como usuario 1000 (no-root)
- Filesystem es read-only
- ServiceAccount con RBAC mínimo asignado
- Pod Security Admission en modo enforce=restricted
- El servicio sigue accesible y funcional
- Todo documentado en tu portafolio
