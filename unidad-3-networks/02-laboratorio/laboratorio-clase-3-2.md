# Laboratorio de la clase 3.2: Aislamiento de Red con NetworkPolicy

## Objetivo del laboratorio y escenario real

**El escenario:** Completaste Lab 3.1 con los 3 servicios **ya desplegados en namespace `default`**:
- `catalog-service:1.0.0` (2 replicas)
- `inventory-service:1.2.0` (2 replicas)
- `payment-service:1.0.0` (2 replicas) + Envoy Gateway (HTTPS validado)

Sin embargo, en la red actual **todos los Pods se comunican libremente** entre sí. Cualquier Pod podría acceder a cualquier otro sin restricción (principio de *Default Allow*).

Ahora necesitas:
1. Aplicar una política de **denegación predeterminada** a payment-service (`Default Deny`)
2. Permitir tráfico **solo desde Envoy Gateway** (Ingress) e **inter-servicios** (Egress: payment → catalog, payment → inventory)
3. Validar que las políticas realmente bloquean tráfico no autorizado

**El objetivo:** Implementar aislamiento L3/L4 con `NetworkPolicy`, demostrando el principio de **mínimo privilegio en red**.

**Salida esperada:** Los 3 servicios siguen funcionando (payment-service orquesta llamadas a catalog e inventory), pero tráfico no autorizado es bloqueado por el CNI.

---

## Requisitos previos

**🔗 Continuidad:** Este laboratorio es la **continuación directa de Lab 3.1**. Asume que:
- ✅ Lab 3.1 está **completamente terminado**
- ✅ Los 3 servicios están corriendo en namespace `default`
- ✅ Envoy Gateway está instalado y funcional
- ✅ HTTPS está validado (certificado autofirmado)
- ✅ Todos los Pods están en estado `Running`

**Verificar estado actual antes de continuar:**

```bash
# Confirmar que los 3 servicios están corriendo en default
kubectl get pods -l app=catalog-service -o wide
kubectl get pods -l app=inventory-service -o wide
kubectl get pods -l app=payment-service -o wide

# Confirmar que los Services existen
kubectl get services

# Confirmar que Envoy Gateway está activo
kubectl get pods -n envoy-gateway-system
kubectl get gateways
```

**Si todos los comandos anteriores muestran recursos activos, estás listo para continuar. Si falta algo, completa Lab 3.1 primero.**

---

## Requisitos técnicos adicionales

- Clúster con **CNI que soporte NetworkPolicy** (Calico, Cilium, Weave, Flannel con plugin, etc.)
- Minikube: debes tener habilitado el addon: `minikube addons enable network-policy`
- `kubectl` y acceso administrativo al clúster

**Nota pedagógica:** NetworkPolicy es **solo especificación**. El CNI es responsable de implementarla. Si el CNI no la soporta, los manifiestos se crean pero no tienen efecto en la red. En Minikube, el addon de network-policy debe estar habilitado explícitamente.

---

## Notas pedagógicas previas

**Qué aprenderás:** 
- Cómo aislar Pods por defecto (Deny All)
- Cómo crear reglas explícitas (Allow List)
- Diferencia entre `Ingress` y `Egress`
- Cómo identificar etiquetas reales de Pods
- Troubleshooting de conectividad red bloqueada

**Por qué es importante:** Sin NetworkPolicy, un compromiso en un Pod podría acceder a todos los demás servicios. Esto es el principio de "Mínimo Privilegio" en red.

---

## Pasos del laboratorio

### Paso 1: Verificar que el CNI soporta NetworkPolicy

**Qué hace:** Confirma que tu clúster tiene soporte para NetworkPolicy habilitado.

**Por qué:** NetworkPolicy es solo especificación; el CNI debe implementarla.

![linux](images/linux.png) **Linux/macOS:**

```bash
# Verificar que la API acepta NetworkPolicy
kubectl api-resources | grep networkpolicies

# Verificar qué CNI está instalado
kubectl get pods -n kube-system -o wide | grep -E "calico|cilium|weave|flannel"

# En Minikube, verificar si está habilitado
minikube addons list | grep network-policy

# Si no está, habilitarlo:
minikube addons enable network-policy
```

![win](images/windows.png) **Windows (PowerShell):**

```powershell
# Verificar API
kubectl api-resources | Select-String "networkpolicies"

# Verificar CNI
kubectl get pods -n kube-system -o wide

# En Minikube
minikube addons list | Select-String "network-policy"

# Habilitar si es necesario
minikube addons enable network-policy
```

**Qué observar:**
- `networkpolicies.networking.k8s.io` debe aparecer en la salida
- Un Pod de CNI (calico-node, cilium-agent, etc.) debe estar ejecutándose en kube-system

**Nota:** La presencia de la API no significa que el CNI la implemente. Validarás esto con las pruebas reales.

---

### Paso 2: Inspeccionar etiquetas actuales de Pods

**Qué hace:** Identifica qué etiquetas tienen los Pods para usar en las políticas.

**Por qué:** NetworkPolicy usa `podSelector.matchLabels` para elegir Pods. Necesitas saber las etiquetas REALES.

![linux](images/linux.png) **Linux/macOS:**

```bash
# Ver todos los Pods de production con sus etiquetas
kubectl get pods -n production --show-labels

# Ver etiquetas específicas de payment-service
kubectl get pods -n production -l app=payment-service --show-labels

# Ver etiquetas de Envoy Gateway proxy (datos)
kubectl get pods -n envoy-gateway-system --show-labels | head -20

# Identifica cuál es el Pod que maneja tráfico (busca "envoy" en el nombre)
# Generalmente es "envoy-xxxxx" en el namespace envoy-gateway-system
PROXY_POD=$(kubectl get pods -n envoy-gateway-system -o jsonpath='{.items[0].metadata.name}')
echo "Proxy Pod: $PROXY_POD"

# Ver etiquetas EXACTAS del proxy
kubectl get pod $PROXY_POD -n envoy-gateway-system -o yaml | grep -A 20 "labels:"
```

![win](images/windows.png) **Windows (PowerShell):**

```powershell
kubectl get pods -n production --show-labels

kubectl get pods -n production -l app=payment-service --show-labels

kubectl get pods -n envoy-gateway-system --show-labels | Select-Object -First 20

# Guardar etiquetas del proxy para usarlas después
$PROXY_POD = kubectl get pods -n envoy-gateway-system -o jsonpath='{.items[0].metadata.name}'
Write-Host "Proxy Pod: $PROXY_POD"

kubectl get pod $PROXY_POD -n envoy-gateway-system -o yaml | Select-String -Context 0,20 "labels:"
```

**Qué observar:**
- Pods de payment-service deben tener `app: payment-service`
- Pods de catalog-service deben tener `app: catalog-service`
- Pods de inventory-service deben tener `app: inventory-service`
- El proxy de Envoy debe tener etiquetas identificables (probablemente `app: envoy` o similar)

**Nota pedagógica:** Estos labels vinieron de tus manifiestos K8s de Lab 3.1. Son arbitrarios pero consistentes.

---

### Paso 3: Crear política Default Deny para payment-service

**Qué hace:** Aísla completamente payment-service (bloquea Ingress y Egress).

**Por qué:** Comienza con "bloquear todo", luego abre explícitamente lo necesario (Whitelist).

**Crear archivo `payment-deny-all.yaml`:**

Genera el archivo con el siguiente contenido:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: payment-deny-all
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: payment-service
  policyTypes:
  - Ingress
  - Egress
  # Intencionalmente vacío: niega TODO
```

**Aplicar política:**

```bash
kubectl apply -f payment-deny-all.yaml

kubectl get networkpolicy -n production
kubectl describe networkpolicy payment-deny-all -n production
```

**Qué observar:**
- NetworkPolicy creada sin errores
- `policyTypes` contiene `Ingress` y `Egress`
- Sin `ingress` o `egress` rules definidas = denegar TODO

**Nota pedagógica:** En este punto, payment-service **NO PUEDE** hablar con nada:
- No recibe conexiones de Envoy (Ingress bloqueado)
- No puede llamar a catalog/inventory (Egress bloqueado)
- No puede resolver DNS (Egress a puerto 53 bloqueado)

---

### Paso 4: Probar que payment-service está aislado

**Qué hace:** Valida que la política está bloqueando tráfico.

**Por qué:** Confirmar que el CNI realmente implementa NetworkPolicy.

**Desde Lab 3.1, si todavía tienes port-forward activo:**

```bash
# Intentar acceder a payment-service vía HTTPS
# Debería FALLAR (timeout o Connection refused)
curl --cacert payment.crt \
  --resolve payment.local:8443:127.0.0.1 \
  -i https://payment.local:8443/v1/payments \
  --max-time 5

# Si tienes timeout o "Connection refused" → ¡PolicyWorking!
```

**Alternativa (ejecutar desde un Pod autorizado por ahora):**

```bash
# Acceder desde Pod en production (que NO será payment-service)
kubectl run test-access \
  --image=curlimages/curl:latest \
  --namespace production \
  --labels app=test-client \
  --restart=Never \
  --rm -it \
  -- curl -v --connect-timeout 3 http://payment-service:8080/v1/payments
```

**Qué observar:**
- Curl devuelve timeout o error de conexión (es lo esperado)
- El timeout típicamente es ~5 segundos

**Nota pedagógica:** Si FUNCIONA y recibe respuesta JSON, significa:
- El CNI no está aplicando NetworkPolicy, O
- Hay otra política permitiendo el tráfico

En ese caso, verifica con tu proveedor de CNI que esté correctamente habilitado.

---

### Paso 5: Permitir Ingress desde Envoy Gateway

**Qué hace:** Abre un "agujero" en la política para que Envoy pueda alcanzar payment-service.

**Por qué:** payment-service debe ser accesible desde el proxy de Gateway API.

**Primero, identifica las etiquetas exactas del proxy (si no las anotaste en Paso 2):**

```bash
# Linux/macOS
ENVOY_POD=$(kubectl get pods -n envoy-gateway-system -o jsonpath='{.items[0].metadata.name}')
kubectl get pod $ENVOY_POD -n envoy-gateway-system -o yaml | grep -A 5 "labels:"

# Windows
$ENVOY_POD = kubectl get pods -n envoy-gateway-system -o jsonpath='{.items[0].metadata.name}'
kubectl get pod $ENVOY_POD -n envoy-gateway-system -o yaml | Select-String -Context 0,5 "labels:"
```

Anota las etiquetas clave (típicamente `app: envoy` o `gateway.envoyproxy.io/owned-by: <gateway-name>`).

**Crear archivo `allow-payment-ingress.yaml`:**

Genera el archivo con el siguiente contenido:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-payment-ingress
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
          kubernetes.io/metadata.name: envoy-gateway-system
      podSelector:
        matchLabels:
          app: envoy  # AJUSTA ESTA ETIQUETA si tu Pod tiene otra
    ports:
    - protocol: TCP
      port: 8080
```

**Aplicar política:**

```bash
kubectl apply -f allow-payment-ingress.yaml

kubectl describe networkpolicy allow-payment-ingress -n production
```

**Qué observar:**
- NetworkPolicy creada sin errores
- El `from` combina `namespaceSelector` AND `podSelector` (ambas condiciones deben cumplirse)
- Puerto 8080 es el que escucha payment-service

**Nota pedagógica:** Si el Pod proxy NO tiene etiqueta `app: envoy`, la política no coincidirá y Envoy seguirá sin poder acceder. Verifica las etiquetas exactas.

---

### Paso 6: Permitir Egress para DNS

**Qué hace:** Abre puerto 53 (DNS) para que payment-service resuelva nombres.

**Por qué:** Sin DNS, `catalog-service` y `inventory-service` no se resuelven (necesita llamar a CoreDNS).

**Crear archivo `allow-payment-dns.yaml`:**

Genera el archivo con el siguiente contenido:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-payment-dns
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: payment-service
  policyTypes:
  - Egress
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: kube-system
    ports:
    - protocol: UDP
      port: 53
    - protocol: TCP
      port: 53
```

**Aplicar política:**

```bash
kubectl apply -f allow-payment-dns.yaml

kubectl get networkpolicy -n production
```

**Qué observar:**
- Permite Egress a `kube-system` en puerto 53 (UDP y TCP)
- Sin esto, `catalog-service:80` no resolvería a IP

---

### Paso 7: Permitir Egress inter-servicios (opcional pero recomendado)

**Qué hace:** Abre connection desde payment-service hacia catalog e inventory.

**Por qué:** Si payment-service orquesta llamadas a otros servicios, las necesita.

**Crear archivo `allow-payment-egress.yaml`:**

Genera el archivo con el siguiente contenido:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-payment-egress-to-services
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: payment-service
  policyTypes:
  - Egress
  egress:
  # Permitir a catalog-service
  - to:
    - podSelector:
        matchLabels:
          app: catalog-service
    ports:
    - protocol: TCP
      port: 8080
  # Permitir a inventory-service
  - to:
    - podSelector:
        matchLabels:
          app: inventory-service
    ports:
    - protocol: TCP
      port: 8080
```

**Aplicar política:**

```bash
kubectl apply -f allow-payment-egress.yaml
```

**Qué observar:**
- Dos bloques `to:` para dos servicios diferentes
- Ambos al puerto 8080 (el puerto del Pod, no el Service)

---

### Paso 8: Validar que payment-service vuelve a funcionar

**Qué hace:** Confirma que después de permitir tráfico, todo funciona.

**Por qué:** Asegurarse que las políticas son efectivas y consistentes.

**Con port-forward de Lab 3.1 activo:**

```bash
# Test HTTPS vía Gateway
curl --cacert payment.crt \
  --resolve payment.local:8443:127.0.0.1 \
  -i https://payment.local:8443/v1/payments \
  -H "Content-Type: application/json" \
  -d '{"productId":"PROD-003","quantity":1,"amount":29.99}'

# Esperado: JSON con transactionId, status (APPROVED o DECLINED)
```

**Alternativa (ejecutar desde otro Pod):**

```bash
kubectl exec -it deployment/payment-service -n production -- \
  curl -i http://inventory-service:80/v1/inventory
```

**Qué observar:**
- Respuesta HTTP exitosa
- Status de pago (APPROVED ~90%, DECLINED ~10% por diseño)

---

### Paso 9: Probar que tráfico no autorizado está bloqueado

**Qué hace:** Confirma que un Pod en otro namespace NO puede alcanzar payment-service.

**Por qué:** Validar que la política realmente aísla.

```bash
# Crear Pod en namespace 'default' (no production)
kubectl run unauthorized-client \
  --image=curlimages/curl:latest \
  --namespace default \
  --restart=Never \
  --rm -it \
  -- curl -v --connect-timeout 5 http://payment-service.production.svc.cluster.local:8080/v1/payments

# Esperado: timeout o "Connection refused"
```

![win](images/windows.png) **Windows (PowerShell):**

```powershell
kubectl run unauthorized-client `
  --image=curlimages/curl:latest `
  --namespace default `
  --restart=Never `
  --rm -it `
  -- curl -v --connect-timeout 5 http://payment-service.production.svc.cluster.local:8080/v1/payments
```

**Qué observar:**
- La conexión NO se establece (timeout típicamente ~5 segundos)
- El CNI está bloqueando en la capa de red

---

### Paso 10: Listar y exportar políticas

**Qué hace:** Documenta todas las políticas aplicadas.

**Por qué:** Necesarias para auditoría, backup y documentación.

```bash
# Ver todas las policies
kubectl get networkpolicy -n production

# Ver detalles completos
kubectl get networkpolicy -n production -o yaml

# Exportar a archivo
kubectl get networkpolicy -n production -o yaml > production-networkpolicies.yaml

# Listar en formato tabla
kubectl get networkpolicy -n production -o wide
```

**Qué observar:**
- Al menos 4 políticas: `payment-deny-all`, `allow-payment-ingress`, `allow-payment-dns`, `allow-payment-egress-to-services`
- Todas en namespace `production`

---

## Troubleshooting

### Problema 1: "Tráfico sigue funcionando aunque aplicué Deny All"

**Causa:** El CNI no está aplicando NetworkPolicy. Es común en:
- Minikube sin `network-policy` addon habilitado
- Clúster Kind sin CNI que soporte NetworkPolicy

**Solución:**

```bash
# En Minikube
minikube addons enable network-policy
minikube ssh sudo sysctl -w net.ipv4.conf.all.forward=1

# En Kind, necesitas instalar CNI como Calico
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/tigera-operator.yaml

# Espera a que el CNI esté listo
kubectl get pods -n calico-system
kubectl get pods -n kube-system | grep calico
```

---

### Problema 2: "La etiqueta del proxy no coincide"

**Causa:** Usaste una etiqueta incorrecta en `podSelector` de la política.

**Solución:**

```bash
# Inspecciona exactamente las etiquetas del proxy
kubectl get pods -n envoy-gateway-system -o yaml | grep -A 20 "labels:"

# Copia la EXACT etiqueta clave-valor
# Ejemplo si ves: "app: envoy" o "gateway.envoyproxy.io/owned-by: payment-gateway"

# Actualiza el archivo allow-payment-ingress.yaml con la etiqueta correcta
kubectl apply -f allow-payment-ingress.yaml

# Verifica que ahora coincida
kubectl get networkpolicy allow-payment-ingress -n production -o yaml | grep -A 10 "podSelector:"
```

---

### Problema 3: "DNS no funciona"

**Síntomas:** Errores como `getaddrinfo failed: Name or service not known` en payment-service cuando llama a catalog-service.

**Causa:** No permitiste tráfico Egress a puerto 53.

**Solución:**

```bash
# Verificar que la política DNS existe
kubectl get networkpolicy allow-payment-dns -n production

# Si no existe, aplicarla
kubectl apply -f allow-payment-dns.yaml

# Probar DNS desde un Pod de payment-service
kubectl run dns-test \
  --image=busybox:1.35 \
  --namespace production \
  --labels app=payment-service \
  --restart=Never \
  --rm -it \
  -- nslookup catalog-service.production.svc.cluster.local
```

---

## Validación Final

**Checklist de evidencia:**

- [ ] NetworkPolicy `payment-deny-all` existe y bloquea todo
- [ ] NetworkPolicy `allow-payment-ingress` permite acceso desde Envoy
- [ ] NetworkPolicy `allow-payment-dns` permite resolución DNS
- [ ] NetworkPolicy `allow-payment-egress-to-services` permite llamadas inter-servicios
- [ ] `curl` a payment-service vía HTTPS devuelve JSON válido
- [ ] Tráfico desde Pod en namespace `default` es bloqueado (timeout)
- [ ] `kubectl get networkpolicy -n production` lista 4+ políticas

**Comandos para documentar:**

```bash
kubectl get networkpolicy -n production -o wide
kubectl describe networkpolicy -n production
kubectl logs deployment/payment-service -n production | grep -i error
curl --cacert payment.crt https://payment.local:8443/v1/payments
```

---

## Reflexión Final

**Preguntas de aprendizaje:**

1. **¿Qué pasaría si solo aplicaras Default Deny de Ingress, pero no de Egress?**
   - Respuesta: payment-service no recibe conexiones, pero PUEDE iniciar conexiones salientes. Esto limita entrada pero no salida.

2. **¿Por qué el selector de Envoy necesita AMBOS namespaceSelector Y podSelector?**
   - Respuesta: Porque ambos se combinan con AND. El Pod debe estar EN envoy-gateway-system Y tener la etiqueta correcta.

3. **¿Qué pasa si un Pod en production tiene la etiqueta `app: payment-service` pero NO es payment-service?**
   - Respuesta: La política lo afectaría igual. Las etiquetas son solo identificadores; la política no valida si "realmente" es payment-service.

---

## Continuidad con Laboratorio 3.3

En el siguiente laboratorio agregarás:
- **RBAC:** Identidad de aplicación (ServiceAccount)
- **SecurityContext:** Ejecutar no-root, read-only filesystem
- **Pod Security Admission:** Perfil `Restricted`

NetworkPolicy + RBAC + SecurityContext = Defensa en profundidad real.

---

## Fuentes primarias

- Kubernetes Docs: NetworkPolicy
  - <https://kubernetes.io/docs/concepts/services-networking/network-policies/>
- Kubernetes Docs: DNS para Servicios
  - <https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/>
- Calico: NetworkPolicy
  - <https://projectcalico.docs.tigera.io/security/kubernetes-network-policy>
- Cilium: Network Policies
  - <https://docs.cilium.io/en/stable/security/policy/>

---

**Laboratorio completado cuando:** Las 4 políticas están aplicadas, payment-service es accesible desde Envoy e inter-servicios, pero bloqueado desde namespaces externos.
- Validar que solo los Pods autorizados pueden ejecutar acciones

**Relación con unidades anteriores:**
- U2 aprendió sobre Services y Deployments
- U3.1 aprendió Gateway API (punto de entrada externo)
- U3.2 (aquí) agrega aislamiento de red con reglas explícitas. `NetworkPolicy` es una posible capa de una estrategia Zero Trust, pero este laboratorio no configura por sí solo identidad, mTLS ni autorización de aplicación.

---

## Recursos Adicionales

- [Kubernetes NetworkPolicy Documentation](https://kubernetes.io/docs/concepts/services-networking/network-policies/)
- [Calico NetworkPolicy Guide](https://docs.tigera.io/calico/latest/reference/resources/networkpolicy)
- [Zero Trust Networking](https://www.nist.gov/publications/zero-trust-architecture)
- [OWASP Network Segmentation](https://cheatsheetseries.owasp.org/cheatsheets/Network_Segmentation_Cheat_Sheet.html)

---

**Laboratorio 3.2 - Versión:** 1.0  
## Fuentes primarias

- Kubernetes Authors. _Network Policies_. <https://kubernetes.io/docs/concepts/services-networking/network-policies/>
- Envoy Gateway. _Quickstart_. <https://gateway.envoyproxy.io/docs/tasks/quickstart/>
