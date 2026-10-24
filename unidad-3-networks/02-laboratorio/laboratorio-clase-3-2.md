# **Laboratorio 3.2:** Aislamiento de Red con NetworkPolicy

Implementar modelo Zero Trust bloqueando todo tráfico por defecto y permitiendo solo rutas específicas entre servicios.

---

## 🎯 Objetivo

Aplicar políticas de red L3/L4 (NetworkPolicies) en el namespace `production` para aislar completamente payment-service, catalog-service e inventory-service, permitiendo tráfico solo desde Ingress Controller y entre servicios autorizados.

---

## 📋 Requisitos Previos

- **Laboratorio 3.1 completado:** Ingress + TLS desplegado
- **Clúster con CNI:** Kubernetes 1.28+ con soporte para NetworkPolicies (Calico, Cilium, etc.)
- **kubectl:** v1.28+
- **Namespace:** production (creado en Lab 3.1)
- **Servicios:** payment-service, catalog-service, inventory-service activos

---

## 🚀 Punto de Partida

Del Lab 3.1:
- ✅ payment-service desplegado y accesible vía Ingress TLS
- ✅ catalog-service y inventory-service heredados de U2
- ⏳ Sin restricciones de red (todos los Pods se comunican libremente)

---

## 📝 Pasos del Laboratorio

### Paso 1: Verificar que CNI soporta NetworkPolicies

#### Linux y macOS

```bash
# Verificar que existe un controlador de red
kubectl get nodes -o wide | grep -E "INTERNAL-IP|Network"

# Verificar API de NetworkPolicy está disponible
kubectl api-resources | grep networkpolicies

# Verificar que Calico o Cilium está instalado (si usas Kind con Calico)
kubectl get ds -n kube-system | grep -E "calico|cilium"
```

#### Windows

```powershell
# Verificar soporte de NetworkPolicy
kubectl api-resources | Select-String "networkpolic"

# En Minikube con Calico
minikube addons enable calico
```

**Esperado:** API `networkpolicies.networking.k8s.io` disponible.

---

### Paso 2: Aplicar Default Deny All (Política de Denegación Total)

Crea el archivo `02-deny-all-networkpolicy.yaml`:

```yaml
---
# Default Deny All: Bloquea todo tráfico de entrada y salida
# en el namespace production
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

Aplica la política:

```bash
# Linux y macOS
kubectl apply -f 02-deny-all-networkpolicy.yaml

# Windows PowerShell
kubectl apply -f 02-deny-all-networkpolicy.yaml
```

Verifica:

```bash
kubectl get networkpolicy -n production
kubectl describe networkpolicy default-deny-all -n production
```

**Resultado esperado:** 
- NetworkPolicy `default-deny-all` creada
- Todos los Pods en production ahora tienen tráfico bloqueado
- Ingress deja de recibir respuestas (HTTP 502)

---

### Paso 3: Permitir Tráfico desde Ingress Controller a payment-service

Crea el archivo `03-allow-ingress-to-payment.yaml`:

```yaml
---
# Permite tráfico desde Ingress Controller al puerto 8080 de payment-service
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-ingress-to-payment
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: payment-service
  policyTypes:
  - Ingress
  ingress:
  - from:
    # Origen: Pod del Ingress Controller (namespace: ingress-nginx)
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: ingress-nginx
    ports:
    - protocol: TCP
      port: 8080
      name: http
```

Aplica la política:

```bash
kubectl apply -f 03-allow-ingress-to-payment.yaml
```

Verifica:

```bash
kubectl get networkpolicy -n production
kubectl get ingress -n production
```

**Esperado:** 
- NetworkPolicy creada
- Ingress ahora recibe HTTP 200 desde payment-service
- `curl https://checkout.local/v1/payment` funciona nuevamente

---

### Paso 4: Permitir Comunicación Inter-Servicios (Opcional pero Recomendado)

Si payment-service necesita llamar a catalog-service o inventory-service, crear NetworkPolicy:

Crea el archivo `04-allow-inter-service.yaml`:

```yaml
---
# Permite que payment-service llame a catalog-service
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-payment-to-catalog
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: catalog-service
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: payment-service
    ports:
    - protocol: TCP
      port: 8080

---
# Permite que payment-service llame a inventory-service
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-payment-to-inventory
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: inventory-service
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: payment-service
    ports:
    - protocol: TCP
      port: 8080
```

Aplica:

```bash
kubectl apply -f 04-allow-inter-service.yaml
```

---

### Paso 5: Permitir DNS (Necesario para nombre.namespace.svc.cluster.local)

Para que los servicios puedan resolver nombres DNS, permitir tráfico a kube-dns:

Crea el archivo `05-allow-dns.yaml`:

```yaml
---
# Permite que todos los Pods consulten DNS (puerto 53)
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns
  namespace: production
spec:
  podSelector: {}
  policyTypes:
  - Egress
  egress:
  # Permitir DNS a kube-dns
  - to:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: kube-system
    ports:
    - protocol: UDP
      port: 53
```

Aplica:

```bash
kubectl apply -f 05-allow-dns.yaml
```

---

### Paso 6: Probar Aislamiento de Red

#### Test 1: Tráfico permitido (desde Ingress a payment-service)

```bash
# Debe funcionar (200 OK)
kubectl port-forward -n ingress-nginx svc/ingress-nginx-controller 8443:443

# En otra terminal
curl -k https://checkout.local:8443/v1/payment
```

**Resultado esperado:** HTTP 200 con JSON de payment-service

---

#### Test 2: Tráfico bloqueado (desde Pod no autorizado)

```bash
# Intentar conectarse desde Pod en namespace 'default' (no autorizado)
kubectl run unauthorized-client \
  --image=curlimages/curl \
  --namespace default \
  --rm -it \
  -- curl --connect-timeout 5 -v http://payment-service.production.svc.cluster.local:8080/v1/payment
```

**Resultado esperado:** Connection timeout (bloqueado por NetworkPolicy)

---

#### Test 3: Tráfico entre servicios (si está permitido)

```bash
# Exec dentro de payment-service Pod
kubectl exec -it -n production deployment/payment-service -- sh

# Dentro del Pod:
# Este debe fallar (si no hay NetworkPolicy de inter-servicio)
curl --connect-timeout 5 http://catalog-service:8080/v1/catalog

# Este debe fallar también
curl --connect-timeout 5 http://inventory-service:8080/v1/inventory
```

**Resultado esperado:** Connection timeout (a menos que hayas aplicado las políticas de inter-servicio)

---

### Paso 7: Auditoría de Políticas Aplicadas

Listar todas las políticas:

```bash
# Ver todas las NetworkPolicies
kubectl get networkpolicy -n production

# Ver detalles de cada una
kubectl describe networkpolicy -n production

# Exportar a YAML (para documentación)
kubectl get networkpolicy -n production -o yaml > networkpolicies-backup.yaml
```

---

## 🔍 Guía de Troubleshooting

### Problema 1: HTTP 502 Bad Gateway después de aplicar Default Deny All

**Síntomas:** Ingress no puede conectarse a payment-service

**Causa:** No aplicaste la NetworkPolicy de allow-ingress-to-payment

**Solución:**

```bash
# Verificar que la política existe
kubectl get networkpolicy -n production

# Si no existe, aplicarla
kubectl apply -f 03-allow-ingress-to-payment.yaml

# Verificar logs del Ingress Controller
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller | grep -i "payment"
```

---

### Problema 2: Los servicios no pueden resolver nombres DNS

**Síntomas:** `curl http://payment-service` falla dentro de un Pod

**Causa:** No aplicaste la política allow-dns

**Solución:**

```bash
# Aplicar allow-dns
kubectl apply -f 05-allow-dns.yaml

# Verificar desde un Pod
kubectl exec -it -n production deployment/payment-service -- nslookup payment-service
```

---

### Problema 3: CNI no soporta NetworkPolicies

**Síntomas:** 
```
NetworkPolicy creada pero tráfico no se bloquea
```

**Causa:** CNI default de Kubernetes (kubenet) no soporta NetworkPolicies

**Solución:**

```bash
# En Minikube, instalar Calico
minikube addons enable calico

# En Kind, agregar Calico al crear cluster
kind create cluster --config - <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
networking:
  networkPolicy: true
EOF

# Instalar CNI manualmente si necesario
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.28.0/manifests/tigera-operator.yaml
```

---

## 📊 Evidencia / Validación

Documentar:

### 1. Default Deny All Aplicado
```bash
kubectl get networkpolicy -n production
kubectl describe networkpolicy default-deny-all -n production
```

### 2. Allow Ingress a Payment Aplicado
```bash
kubectl describe networkpolicy allow-ingress-to-payment -n production
```

### 3. Tráfico desde Ingress Funciona
```bash
curl -k https://checkout.local:8443/v1/payment
```
**Screenshot esperado:** HTTP 200 OK

### 4. Tráfico Bloqueado desde Pod No Autorizado
```bash
kubectl run test-pod --image=curlimages/curl --namespace default --rm -it -- \
  curl --connect-timeout 3 http://payment-service.production.svc.cluster.local:8080/v1/payment
```
**Screenshot esperado:** Connection timeout (bloqueado)

### 5. Listado de Políticas Aplicadas
```bash
kubectl get networkpolicy -n production -o wide
```

---

## 🎓 Reflexión Final

**Preguntas de consolidación:**

1. ¿Cuál es la diferencia entre `default-deny-all` (Ingress + Egress) vs solo Ingress?
   - Respuesta: Default deny-all bloquea ambas direcciones. Solo Ingress permite egress libre (comunicación saliente).

2. ¿Por qué permitir tráfico a kube-dns (puerto 53)?
   - Respuesta: Sin DNS, los Pods no pueden resolver nombres (ej: `payment-service`). Necesitan llamar a kube-dns.

3. ¿Qué sucede si aplicas default-deny-all pero olvidas crear la política de allow-ingress?
   - Respuesta: Ingress devuelve 502 Bad Gateway porque no puede alcanzar los Pods.

---

## 🔗 Continuidad

**Próximo paso (Laboratorio 3.3):**
- Implementar RBAC (ServiceAccounts, Roles, RoleBindings)
- Agregar SecurityContext (no-root, read-only filesystem)
- Validar que solo los Pods autorizados pueden ejecutar acciones

**Relación con unidades anteriores:**
- U2 aprendió sobre Services y Deployments
- U3.1 aprendió Ingress (punto de entrada externo)
- U3.2 (aquí) agrega seguridad de red (Zero Trust)

---

## 📚 Recursos Adicionales

- [Kubernetes NetworkPolicy Documentation](https://kubernetes.io/docs/concepts/services-networking/network-policies/)
- [Calico NetworkPolicy Guide](https://docs.tigera.io/calico/latest/reference/resources/networkpolicy)
- [Zero Trust Networking](https://www.nist.gov/publications/zero-trust-architecture)
- [OWASP Network Segmentation](https://cheatsheetseries.owasp.org/cheatsheets/Network_Segmentation_Cheat_Sheet.html)

---

**Laboratorio 3.2 - Versión:** 1.0  
**Última actualización:** 2026-10-15  
**Estado:** ✅ Listo para docencia
