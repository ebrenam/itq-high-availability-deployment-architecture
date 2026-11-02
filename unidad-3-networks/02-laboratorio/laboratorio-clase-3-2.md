# **Laboratorio 3.2:** Aislamiento de Red con NetworkPolicy

Aplicar aislamiento de red a los Pods seleccionados con una política de denegación predeterminada y reglas explícitas para los flujos necesarios. Este laboratorio trabaja con `NetworkPolicy`; no implementa por sí solo una arquitectura Zero Trust.

---

## 🎯 Objetivo

Aplicar políticas de red L3/L4 en el namespace `production` para aislar los Pods seleccionados en las direcciones `Ingress` y `Egress`, y permitir el tráfico requerido desde el proxy de datos de Envoy Gateway y, opcionalmente, entre servicios. La aplicación de las políticas depende de que el CNI del clúster las soporte.

---

## 📋 Requisitos Previos

- **Laboratorio 3.1 completado:** Gateway API + TLS desplegado
- **Clúster con CNI:** El mismo clúster compatible con Envoy Gateway del Laboratorio 3.1 y con soporte efectivo para NetworkPolicies (Calico, Cilium, etc.).
- **kubectl:** versión compatible con el API Server del clúster.
- **Namespace:** production (creado en Lab 3.1)
- **Servicio requerido:** `payment-service` activo. `catalog-service` e `inventory-service` se necesitan solo si se realiza la prueba interservicios opcional y están desplegados en `production`.

---

## 🚀 Punto de Partida

Del Lab 3.1:
- ✅ payment-service de demostración desplegado y accesible vía Gateway API + TLS
- ⏳ catalog-service e inventory-service opcionales para probar reglas interservicios
- ⏳ Sin restricciones de red (todos los Pods se comunican libremente)

---

## 📝 Pasos del Laboratorio

### Paso 1: Verificar que CNI soporta NetworkPolicies

#### Linux y macOS

```bash
# Inspeccionar los Pods del sistema para identificar el CNI instalado
kubectl get pods -n kube-system -o wide

# Verificar API de NetworkPolicy está disponible
kubectl api-resources | grep networkpolicies

# Si usas Calico o Cilium, comprobar sus Pods
kubectl get pods -A | grep -E "calico|cilium"
```

#### Windows

```powershell
# Verificar soporte de NetworkPolicy
kubectl api-resources | Select-String "networkpolic"

# Identificar los Pods del CNI instalado
kubectl get pods -A -o wide
```

**Esperado:** La API `networkpolicies.networking.k8s.io` está disponible y puedes identificar el CNI instalado. Que la API acepte objetos `NetworkPolicy` no confirma por sí solo que el CNI aplique sus reglas; lo validarás con las pruebas de conectividad de este laboratorio.

---

### Paso 2: Aislar `payment-service` por defecto

Crea el archivo `02-default-deny-payment.yaml`:

```yaml
---
# Aísla los Pods de payment-service para Ingress y Egress.
# Los demás Pods del namespace no quedan seleccionados por esta política.
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-payment
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: payment-service
  policyTypes:
  - Ingress
  - Egress
```

Aplica la política:

```bash
# Linux y macOS
kubectl apply -f 02-default-deny-payment.yaml

# Windows PowerShell
kubectl apply -f 02-default-deny-payment.yaml
```

Verifica:

```bash
kubectl get networkpolicy -n production
kubectl describe networkpolicy default-deny-payment -n production
```

**Resultado esperado:** 
- NetworkPolicy `default-deny-payment` creada
- Todos los Pods etiquetados `app: payment-service` quedan aislados para `Ingress` y `Egress`, salvo las respuestas de conexiones permitidas y las excepciones propias de la implementación de red. Otros Pods del namespace no quedan seleccionados por esta política.
- Las conexiones afectadas dejan de funcionar. El síntoma visible (por ejemplo, timeout o error HTTP) depende del CNI y del punto donde se aplique el bloqueo; no se garantiza un HTTP 502.

---

### Paso 3: Identificar el proxy de datos y permitir su tráfico a payment-service

La política debe seleccionar los **Pods del proxy de datos** de Envoy Gateway, no asumir que estos están en el namespace del controlador. Identifica el Pod que maneja el tráfico y sus etiquetas reales:

```bash
kubectl get pods -A -o wide | grep -i envoy
kubectl get pods -n envoy-gateway-system --show-labels
```

Si el Pod de datos no está en `envoy-gateway-system`, sustituye ese namespace en el manifiesto. El `podSelector` del ejemplo contiene marcadores: reemplázalos por una etiqueta estable que comparta el proxy de datos antes de aplicar el archivo. El selector de namespace y el de Pod dentro del mismo elemento `from` se combinan con AND.

Crea el archivo `03-allow-ingress-to-payment.yaml`:

```yaml
---
# Permite tráfico desde los Pods proxy de datos identificados.
# Reemplaza los marcadores del selector por una etiqueta real antes de aplicar.
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
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: envoy-gateway-system
      podSelector:
        matchLabels:
          REEMPLAZAR_CLAVE_LABEL: REEMPLAZAR_VALOR_LABEL
    ports:
    - protocol: TCP
      port: 8080
```

Aplica la política:

```bash
kubectl apply -f 03-allow-ingress-to-payment.yaml
```

Verifica:

```bash
kubectl get networkpolicy -n production
kubectl get gateway,httproute -n production
```

**Esperado:** 
- NetworkPolicy creada
- El CNI permite el tráfico entrante desde el namespace indicado al puerto 8080 de los Pods seleccionados de `payment-service`. Si el proxy de datos usa otro namespace, corrige el selector antes de aplicar la política.
- Una solicitud a un endpoint válido de payment-service debe volver a funcionar; verifica el código HTTP y el cuerpo que devuelve la aplicación.
- `curl --cacert checkout.crt --resolve checkout.local:8443:127.0.0.1 https://checkout.local:8443/v1/payment` funciona nuevamente

---

### Paso 4: Permitir Comunicación Inter-Servicios (Opcional pero Recomendado)

El backend de demostración del Laboratorio 3.1 no llama a otros servicios. Esta sección es un ejercicio opcional de políticas: despliega `catalog-service` e `inventory-service` con imágenes disponibles en el namespace `production`, o sáltala. Para permitir un flujo real entre servicios, se deben habilitar tanto el `Ingress` del destino como el `Egress` del origen. En este ejemplo, los tres servicios están en `production` y escuchan en el puerto 8080 del Pod. Ajusta etiquetas y puertos si tus manifiestos usan otros valores.

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

---
# Permite a payment-service iniciar conexiones hacia catalog-service e inventory-service
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
  - to:
    - podSelector:
        matchLabels:
          app: catalog-service
    ports:
    - protocol: TCP
      port: 8080
  - to:
    - podSelector:
        matchLabels:
          app: inventory-service
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
# Permite que payment-service consulte Pods de kube-system
# en el puerto DNS (UDP y TCP 53).
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: payment-service
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
    - protocol: TCP
      port: 53
```

Esta regla permite el puerto 53 a los Pods de `kube-system`, no exclusivamente a CoreDNS. Para restringirla, comprueba las etiquetas reales de los Pods DNS en tu clúster y añade un `podSelector` junto al `namespaceSelector`. Algunos clústeres usan NodeLocal DNS; en ese caso, adapta la regla a la arquitectura DNS y al CNI instalados.

Aplica:

```bash
kubectl apply -f 05-allow-dns.yaml
```

---

### Paso 6: Probar Aislamiento de Red

#### Test 1: Tráfico permitido (desde Gateway a payment-service)

```bash
# Conserva el port-forward al Service proxy creado por Envoy Gateway (Lab 3.1).
# En otra terminal:
curl --cacert checkout.crt \
  --resolve checkout.local:8443:127.0.0.1 \
  -i https://checkout.local:8443/v1/payment
```

**Resultado esperado:** Una respuesta HTTP válida del endpoint `/v1/payment`. El código y el cuerpo deben coincidir con la implementación de `payment-service`.

---

#### Test 2: Tráfico bloqueado (desde Pod no autorizado)

```bash
# Intentar conectarse desde Pod en namespace 'default' (no autorizado)
kubectl run unauthorized-client \
  --image=curlimages/curl \
  --namespace default \
  --rm -it \
  --restart=Never \
  -- curl --fail --connect-timeout 5 -v http://payment-service.production.svc.cluster.local/v1/payment
```

**Resultado esperado:** La solicitud no obtiene una respuesta HTTP exitosa de payment-service. El error concreto depende del CNI; no se garantiza que sea un timeout. Si no resuelve el nombre DNS, revisa también el Paso 5.

---

#### Test 3: Tráfico entre servicios (si aplicaste el Paso 4)

```bash
# Simula un Pod de payment-service para probar las reglas de Egress e Ingress.
# Ejecuta en production con la etiqueta seleccionada por las políticas.
kubectl run payment-policy-test \
  --image=curlimages/curl \
  --namespace production \
  --labels app=payment-service \
  --rm -it \
  --restart=Never \
  -- curl --connect-timeout 5 -i http://catalog-service:8080/v1/products

# El Service de inventory-service expone el puerto 80 y lo dirige al 8080 del Pod.
kubectl run payment-policy-test \
  --image=curlimages/curl \
  --namespace production \
  --labels app=payment-service \
  --rm -it \
  --restart=Never \
  -- curl --connect-timeout 5 -i http://inventory-service/v1/inventory
```

**Resultado esperado:** Si aplicaste las políticas del Paso 4 y el DNS del Paso 5 está permitido, ambas conexiones deben llegar a sus servicios. El catálogo puede responder según su lógica de aplicación; inventario debe responder con su estado. Si omitiste el Paso 4, no se permite el flujo de `payment-service` a esos servicios. El resultado específico al denegarlo depende del CNI. Comprueba también que las rutas HTTP sean válidas en cada aplicación.

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

### Problema 1: Envoy Gateway no alcanza payment-service después de aislarlo

**Síntomas:** La solicitud a través de Gateway API falla (por ejemplo, con HTTP 502 o timeout).

**Posibles causas:** No aplicaste la NetworkPolicy `allow-ingress-to-payment`, el selector no coincide con las etiquetas del Pod, el puerto destino no es 8080 o el CNI no aplica políticas de red.

**Solución:**

```bash
# Verificar que la política existe
kubectl get networkpolicy -n production

# Si no existe, aplicarla
kubectl apply -f 03-allow-ingress-to-payment.yaml

# Identificar y revisar logs de los Pods proxy de datos de Envoy Gateway
kubectl get pods -A -o wide | grep -i envoy
kubectl logs -n NAMESPACE_DEL_PROXY POD_DEL_PROXY
```

---

### Problema 2: Los servicios no pueden resolver nombres DNS

**Síntomas:** El nombre del Service no resuelve desde un Pod de `production`.

**Posibles causas:** No aplicaste la política `allow-dns`, el selector no coincide con los Pods DNS o el clúster usa una arquitectura DNS que requiere otra regla.

**Solución:**

```bash
# Aplicar allow-dns
kubectl apply -f 05-allow-dns.yaml

# El backend distroless no incluye nslookup; usa un Pod temporal seleccionado
# por la misma política de Egress que payment-service.
kubectl run dns-test \
  --image=busybox:1.36.1 \
  --namespace production \
  --labels app=payment-service \
  --rm -it \
  --restart=Never \
  -- nslookup payment-service.production.svc.cluster.local
```

---

### Problema 3: Las NetworkPolicies existen, pero no se aplica el bloqueo

**Síntomas:** 
```
NetworkPolicy creada pero tráfico no se bloquea
```

**Causa:** La API de Kubernetes acepta y guarda los objetos `NetworkPolicy`, pero el CNI instalado puede no aplicar sus reglas o no estar configurado para hacerlo. La presencia de la API no confirma el soporte efectivo.

**Solución:**

Verifica qué CNI está instalado y confirma en su documentación cómo habilitar NetworkPolicy para tu distribución y versión de Kubernetes. No instales un segundo CNI sobre un clúster activo sin seguir el procedimiento de migración recomendado para ese entorno. Después, repite los Tests 1 y 2 para comprobar que el tráfico permitido y el denegado se comportan como se espera.

---

## 📊 Evidencia / Validación

Documentar:

### 1. Denegación predeterminada de `payment-service`
```bash
kubectl get networkpolicy -n production
kubectl describe networkpolicy default-deny-payment -n production
```

### 2. Allow Ingress a Payment Aplicado
```bash
kubectl describe networkpolicy allow-ingress-to-payment -n production
```

### 3. Tráfico desde Gateway Funciona
```bash
curl --cacert checkout.crt \
  --resolve checkout.local:8443:127.0.0.1 \
  https://checkout.local:8443/v1/payment
```
**Screenshot esperado:** Respuesta HTTP del endpoint de payment-service. El código y el cuerpo dependen de la implementación de la aplicación.

### 4. Tráfico Bloqueado desde Pod No Autorizado
```bash
kubectl run test-pod --image=curlimages/curl --namespace default --rm -it --restart=Never -- \
  curl --fail --connect-timeout 3 http://payment-service.production.svc.cluster.local/v1/payment
```
**Screenshot esperado:** La solicitud no obtiene una respuesta HTTP exitosa. El error concreto depende del CNI.

### 5. Listado de Políticas Aplicadas
```bash
kubectl get networkpolicy -n production -o wide
```

---

## 🎓 Reflexión Final

**Preguntas de consolidación:**

1. ¿Cuál es la diferencia entre denegar por defecto `Ingress` y `Egress`, o solo `Ingress`?
   - Respuesta: esta política aísla los Pods seleccionados para ambas direcciones. En el laboratorio, el selector incluye solo `payment-service`; otros Pods no quedan aislados por ella. Una política que solo aísla `Ingress` deja permitido `Egress`, siempre que ninguna otra política aisle también esa dirección. Las conexiones de respuesta a flujos permitidos se admiten.

2. ¿Por qué permitir tráfico a kube-dns (puerto 53)?
   - Respuesta: Si el Egress está aislado, las consultas DNS también necesitan una regla de salida. DNS puede usar UDP y TCP por el puerto 53; la regla debe ajustarse a los selectores y la arquitectura DNS del clúster.

3. ¿Qué sucede si aplicas la denegación predeterminada a `payment-service` pero olvidas crear la política de entrada permitida?
   - Respuesta: El tráfico desde el proxy de datos de Envoy Gateway a los Pods seleccionados no está permitido; la solicitud falla, pero el síntoma exacto depende del CNI y de la implementación del proxy.

---

## 🔗 Continuidad

**Próximo paso (Laboratorio 3.3):**
- Implementar RBAC (ServiceAccounts, Roles, RoleBindings)
- Agregar SecurityContext (no-root, read-only filesystem)
- Validar que solo los Pods autorizados pueden ejecutar acciones

**Relación con unidades anteriores:**
- U2 aprendió sobre Services y Deployments
- U3.1 aprendió Gateway API (punto de entrada externo)
- U3.2 (aquí) agrega aislamiento de red con reglas explícitas. `NetworkPolicy` es una posible capa de una estrategia Zero Trust, pero este laboratorio no configura por sí solo identidad, mTLS ni autorización de aplicación.

---

## 📚 Recursos Adicionales

- [Kubernetes NetworkPolicy Documentation](https://kubernetes.io/docs/concepts/services-networking/network-policies/)
- [Calico NetworkPolicy Guide](https://docs.tigera.io/calico/latest/reference/resources/networkpolicy)
- [Zero Trust Networking](https://www.nist.gov/publications/zero-trust-architecture)
- [OWASP Network Segmentation](https://cheatsheetseries.owasp.org/cheatsheets/Network_Segmentation_Cheat_Sheet.html)

---

**Laboratorio 3.2 - Versión:** 1.0  
## Fuentes primarias

- Kubernetes Authors. _Network Policies_. <https://kubernetes.io/docs/concepts/services-networking/network-policies/>
- Envoy Gateway. _Quickstart_. <https://gateway.envoyproxy.io/docs/tasks/quickstart/>
