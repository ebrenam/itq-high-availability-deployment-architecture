# **Laboratorio 3.3:** Endurecimiento de Seguridad con RBAC y SecurityContext

Implementar Control de Acceso Basado en Roles (RBAC) y restricciones de seguridad a nivel de Pod para cumplir con estándares de seguridad Kubernetes.

---

## 🎯 Objetivo

Aplicar principio de mínimo privilegio mediante RBAC y SecurityContext, asegurando que:
1. payment-service se ejecuta con usuario no-root
2. El filesystem es read-only
3. No hay escalación de privilegios
4. ServiceAccount tiene permisos limitados a recursos específicos

---

## 📋 Requisitos Previos

- **Laboratorio 3.1 y 3.2 completados:** Ingress y NetworkPolicies desplegadas
- **Kubectl:** v1.28+ (para comandos `auth can-i`)
- **Namespace:** production (con NetworkPolicies activas)
- **Clúster:** Soporte para Pod Security Standards (PSS)
- **Herramientas opcionales:** trivy (para escaneo de vulnerabilidades)

---

## 🚀 Punto de Partida

Del Lab 3.2:
- ✅ payment-service con NetworkPolicies aplicadas
- ✅ Tráfico asegurado de red (L3/L4)
- ⏳ Sin restricciones de identidad o proceso (RBAC/SecurityContext)

---

## 📝 Pasos del Laboratorio

### Paso 1: Configurar Pod Security Standards (PSS) en el Namespace

Habilitar el perfil `restricted` en el namespace production para forzar SecurityContext mínimo:

#### Linux y macOS

```bash
# Etiquetar namespace con Pod Security Standard 'restricted'
kubectl label namespace production \
  pod-security.kubernetes.io/enforce=restricted \
  pod-security.kubernetes.io/enforce-version=latest \
  --overwrite

# Verificar que se aplicó
kubectl describe namespace production | grep pod-security
```

#### Windows

```powershell
kubectl label namespace production `
  pod-security.kubernetes.io/enforce=restricted `
  pod-security.kubernetes.io/enforce-version=latest `
  --overwrite

kubectl describe namespace production | Select-String "pod-security"
```

**Esperado:** Etiquetas `pod-security.kubernetes.io/enforce=restricted` aplicadas.

---

### Paso 2: Crear ServiceAccount de Mínimo Privilegio

Crea el archivo `06-rbac-payment-service.yaml`:

```yaml
---
# ServiceAccount para payment-service (identidad)
apiVersion: v1
kind: ServiceAccount
metadata:
  name: payment-service-sa
  namespace: production
  labels:
    app: payment-service

---
# Role: Permisos mínimos (solo leer ConfigMaps)
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: payment-service-role
  namespace: production
rules:
# Permite leer ConfigMaps (para configuración)
- apiGroups: [""]
  resources: ["configmaps"]
  verbs: ["get", "list", "watch"]
# Permite leer Secrets (para credenciales)
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get"]

---
# RoleBinding: Vincula el ServiceAccount con el Role
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: payment-service-binding
  namespace: production
subjects:
- kind: ServiceAccount
  name: payment-service-sa
  namespace: production
roleRef:
  kind: Role
  name: payment-service-role
  apiGroup: rbac.authorization.k8s.io
```

Aplica el manifiesto:

```bash
# Linux, macOS y Windows
kubectl apply -f 06-rbac-payment-service.yaml
```

Verifica:

```bash
# Ver ServiceAccount
kubectl get sa -n production
kubectl describe sa payment-service-sa -n production

# Ver Role
kubectl get role -n production
kubectl describe role payment-service-role -n production

# Ver RoleBinding
kubectl get rolebinding -n production
kubectl describe rolebinding payment-service-binding -n production
```

**Esperado:**
- ServiceAccount `payment-service-sa` creada
- Role `payment-service-role` con permisos sobre configmaps y secrets
- RoleBinding conectando SA → Role

---

### Paso 3: Actualizar Deployment con SecurityContext

Crea el archivo `07-payment-hardened.yaml`:

```yaml
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: payment-service
  namespace: production
  labels:
    app: payment-service
    version: v1.0.0
spec:
  replicas: 2
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  selector:
    matchLabels:
      app: payment-service
  template:
    metadata:
      labels:
        app: payment-service
        version: v1.0.0
    spec:
      # Usar ServiceAccount de mínimo privilegio
      serviceAccountName: payment-service-sa
      automountServiceAccountToken: true
      
      # SecurityContext a nivel de Pod
      securityContext:
        runAsNonRoot: true          # Debe ejecutarse como usuario no-root
        runAsUser: 1000             # UID 1000 (usuario 'appuser')
        runAsGroup: 1000            # GID 1000
        fsGroup: 1000               # Grupo propietario de volúmenes
        seccompProfile:
          type: RuntimeDefault      # Usar perfil seccomp default
      
      containers:
      - name: payment-service
        image: ebrena/payment-service:1.0.0
        imagePullPolicy: Always
        
        ports:
        - containerPort: 8080
          name: http
        
        # SecurityContext a nivel de Contenedor
        securityContext:
          allowPrivilegeEscalation: false    # No permitir escalación de privilegios
          readOnlyRootFilesystem: true       # Filesystem raíz read-only
          capabilities:
            drop:                            # Eliminar todas las capabilities
            - ALL
            add:                             # Agregar solo lo necesario
            - NET_BIND_SERVICE               # (solo si es necesario)
        
        # Volumen temporal para escritura
        volumeMounts:
        - name: tmp
          mountPath: /tmp
        - name: cache
          mountPath: /home/appuser/.cache
        
        livenessProbe:
          httpGet:
            path: /q/health/live
            port: 8080
          initialDelaySeconds: 10
          periodSeconds: 10
        
        readinessProbe:
          httpGet:
            path: /q/health/ready
            port: 8080
          initialDelaySeconds: 10
          periodSeconds: 10
        
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
      
      # Volúmenes temporales (emptyDir para /tmp)
      volumes:
      - name: tmp
        emptyDir: {}
      - name: cache
        emptyDir: {}

---
apiVersion: v1
kind: Service
metadata:
  name: payment-service
  namespace: production
  labels:
    app: payment-service
spec:
  type: ClusterIP
  ports:
  - port: 80
    targetPort: 8080
    name: http
  selector:
    app: payment-service
```

Aplica el deployment endurecido:

```bash
# Eliminar deployment antiguo
kubectl delete deployment payment-service -n production

# Aplicar nuevo deployment con SecurityContext
kubectl apply -f 07-payment-hardened.yaml
```

Verifica:

```bash
# Ver pods
kubectl get pods -n production -l app=payment-service

# Describir pod para ver SecurityContext
kubectl describe pod -n production deployment/payment-service | grep -A 20 "Security Context"

# Ver que los pods están Running
kubectl get pods -n production
```

**Esperado:**
- Pods en estado `Running`
- SecurityContext con `runAsNonRoot: true`
- `readOnlyRootFilesystem: true`

---

### Paso 4: Validar Permisos RBAC con `kubectl auth can-i`

Probar qué acciones el ServiceAccount puede/no puede realizar:

```bash
# Acciones PERMITIDAS
# ==================

# Ver ConfigMaps (permitido)
kubectl auth can-i list configmaps \
  --as=system:serviceaccount:production:payment-service-sa \
  -n production
# Resultado esperado: yes

# Obtener un ConfigMap (permitido)
kubectl auth can-i get configmaps \
  --as=system:serviceaccount:production:payment-service-sa \
  -n production
# Resultado esperado: yes

# Acciones DENEGADAS
# ==================

# Eliminar Pods (denegado)
kubectl auth can-i delete pods \
  --as=system:serviceaccount:production:payment-service-sa \
  -n production
# Resultado esperado: no

# Crear Deployments (denegado)
kubectl auth can-i create deployments \
  --as=system:serviceaccount:production:payment-service-sa \
  -n production
# Resultado esperado: no

# Actualizar Secrets (denegado)
kubectl auth can-i update secrets \
  --as=system:serviceaccount:production:payment-service-sa \
  -n production
# Resultado esperado: no

# Acceso de cluster-admin
# ========================

# Ver que otro ServiceAccount (default) NO tiene permisos
kubectl auth can-i delete pods \
  --as=system:serviceaccount:production:default \
  -n production
# Resultado esperado: no
```

**Esperado:**
- `list/get configmaps` → yes (permitido)
- `delete pods` → no (denegado)
- `create deployments` → no (denegado)

---

### Paso 5: Probar SecurityContext no-root

Verificar que el contenedor se ejecuta como usuario no-root:

```bash
# Ejecutar comandos dentro del Pod
kubectl exec -it -n production deployment/payment-service -- id

# Resultado esperado:
# uid=1000 gid=1000 groups=1000
# (NO uid=0 que sería root)

# Intentar escribir en filesystem raíz (debe fallar)
kubectl exec -it -n production deployment/payment-service -- touch /test.txt

# Resultado esperado:
# Read-only file system (error)

# Pero puede escribir en /tmp (permitido)
kubectl exec -it -n production deployment/payment-service -- touch /tmp/test.txt

# Resultado esperado: Success
```

**Validación esperada:**
- UID != 0 (no es root)
- No puede escribir en / (read-only)
- Puede escribir en /tmp (emptyDir permitido)

---

### Paso 6: Crear ServiceAccounts para Otros Servicios

Aplicar el mismo patrón a catalog-service e inventory-service:

Crea el archivo `08-rbac-all-services.yaml`:

```yaml
---
# CATALOG SERVICE
apiVersion: v1
kind: ServiceAccount
metadata:
  name: catalog-service-sa
  namespace: production

---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: catalog-service-role
  namespace: production
rules:
- apiGroups: [""]
  resources: ["configmaps"]
  verbs: ["get", "list"]

---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: catalog-service-binding
  namespace: production
subjects:
- kind: ServiceAccount
  name: catalog-service-sa
  namespace: production
roleRef:
  kind: Role
  name: catalog-service-role
  apiGroup: rbac.authorization.k8s.io

---
# INVENTORY SERVICE
apiVersion: v1
kind: ServiceAccount
metadata:
  name: inventory-service-sa
  namespace: production

---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: inventory-service-role
  namespace: production
rules:
- apiGroups: [""]
  resources: ["configmaps"]
  verbs: ["get", "list"]

---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: inventory-service-binding
  namespace: production
subjects:
- kind: ServiceAccount
  name: inventory-service-sa
  namespace: production
roleRef:
  kind: Role
  name: inventory-service-role
  apiGroup: rbac.authorization.k8s.io
```

Aplica:

```bash
kubectl apply -f 08-rbac-all-services.yaml
```

---

### Paso 7: Escaneo de Vulnerabilidades (Opcional pero Recomendado)

Usar Trivy para escanear imágenes antes de desplegar:

```bash
# Instalar trivy (si no está instalado)
# macOS
brew install aquasecurity/trivy/trivy

# Linux
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | apt-key add -
echo "deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/trivy.list
apt-get update && apt-get install trivy

# Escanear imagen
trivy image ebrena/payment-service:1.0.0

# Salir con error si hay críticas
trivy image --exit-code 1 --severity CRITICAL ebrena/payment-service:1.0.0
```

**Esperado:** Reporte de vulnerabilidades encontradas (o ninguna si está bien endurecida).

---

## 🔍 Guía de Troubleshooting

### Problema 1: Pod rechazado por PSS (Restricted)

**Síntomas:**
```
Error creating pod: violates PodSecurityPolicy
```

**Causa:** Pod no cumple con restricciones del estándar Restricted

**Solución:** Asegurar que el Pod tiene:
```yaml
securityContext:
  runAsNonRoot: true
  readOnlyRootFilesystem: true
  capabilities:
    drop:
    - ALL
```

---

### Problema 2: Pod no puede escribir en /tmp

**Síntomas:**
```
Permission denied: /tmp/file.txt
```

**Causa:** Falta emptyDir montado en /tmp

**Solución:** Agregar volumen:
```yaml
volumes:
- name: tmp
  emptyDir: {}

volumeMounts:
- name: tmp
  mountPath: /tmp
```

---

### Problema 3: ServiceAccount no tiene permisos necesarios

**Síntomas:** Aplicación falla con error de permisos

**Solución:** Verificar con `kubectl auth can-i` y expandir Role si es necesario:

```bash
# Ver qué se necesita
kubectl auth can-i <action> <resource> \
  --as=system:serviceaccount:production:payment-service-sa \
  -n production
```

---

## 📊 Evidencia / Validación

Documentar:

### 1. Pod Security Standard Aplicado
```bash
kubectl describe namespace production | grep pod-security
```

### 2. ServiceAccount Creada
```bash
kubectl get sa -n production
kubectl describe sa payment-service-sa -n production
```

### 3. RBAC Aplicado
```bash
kubectl get role,rolebinding -n production
```

### 4. SecurityContext Activo
```bash
kubectl describe pod -n production deployment/payment-service | grep -A 15 "Security Context"
```

### 5. Verificación de No-Root
```bash
kubectl exec -n production deployment/payment-service -- id
# Esperado: uid=1000 (no 0)
```

### 6. Filesystem Read-Only Verificado
```bash
kubectl exec -n production deployment/payment-service -- touch /test.txt
# Esperado: Read-only file system (error)

kubectl exec -n production deployment/payment-service -- touch /tmp/test.txt
# Esperado: Success
```

### 7. Permisos RBAC Validados
```bash
kubectl auth can-i list configmaps \
  --as=system:serviceaccount:production:payment-service-sa \
  -n production
# Esperado: yes

kubectl auth can-i delete pods \
  --as=system:serviceaccount:production:payment-service-sa \
  -n production
# Esperado: no
```

---

## 🎓 Reflexión Final

**Preguntas de consolidación:**

1. ¿Cuál es la diferencia entre `runAsNonRoot` y `readOnlyRootFilesystem`?
   - Respuesta: runAsNonRoot fuerza a no ser root (identidad), readOnlyRootFilesystem protege archivos de sistema (permisos).

2. ¿Por qué es importante capabiltiies `drop: ALL`?
   - Respuesta: Elimina funciones peligrosas (ej: ptrace, SYS_ADMIN) que podrían permitir escalación de privilegios.

3. ¿Cómo verifica Kubernetes que un Pod cumple con Pod Security Standard Restricted?
   - Respuesta: El admission controller verifica en tiempo de creación que el Pod tiene SecurityContext requerido.

---

## 🔗 Continuidad

**Después del Lab 3.3:**
- ✅ Ingress + TLS seguro (Lab 3.1)
- ✅ NetworkPolicies bloqueando tráfico no autorizado (Lab 3.2)
- ✅ RBAC + SecurityContext limitando privilegios (Lab 3.3)
- ✅ **Unidad 3 completa: Arquitectura cloud-native segura**

**Próxima unidad (U4):**
- Automatización con CI/CD
- Pipelines de build y deploy
- GitOps en Kubernetes

---

## 📚 Recursos Adicionales

- [Kubernetes SecurityContext](https://kubernetes.io/docs/tasks/configure-pod-container/security-context/)
- [Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/)
- [RBAC Authorization](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)
- [Trivy Vulnerability Scanner](https://aquasecurity.github.io/trivy/)
- [OWASP Kubernetes Top 10](https://owasp.org/www-community/vulnerabilities/Kubernetes_Top_10)

---

**Laboratorio 3.3 - Versión:** 1.0  
**Última actualización:** 2026-10-15  
**Estado:** ✅ Listo para docencia
