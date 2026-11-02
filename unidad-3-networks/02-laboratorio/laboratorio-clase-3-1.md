# **Laboratorio 3.1:** Exposición con Gateway API y TLS

Crear un endpoint de pagos de demostración y exponerlo por HTTPS con Gateway API y Envoy Gateway. La práctica también compara este modelo con Ingress, una API estable pero congelada.

> **Alcance:** El endpoint de pagos es una respuesta HTTP estática para practicar enrutamiento y TLS; no procesa pagos ni debe usarse en producción. El certificado es autofirmado. TLS termina en el Gateway; el tramo Gateway–Pod es HTTP.

---

## 🎯 Objetivos

- Instalar Envoy Gateway y sus CRD de Gateway API con una versión fijada.
- Crear un servicio interno y enrutar hacia él por hostname.
- Terminar TLS en un listener HTTPS y redirigir HTTP a HTTPS.
- Verificar certificados sin desactivar su validación.

## 📋 Requisitos previos

- Kubernetes `v1.33`–`v1.36` para Envoy Gateway `v1.9.x` (confirma la compatibilidad exacta antes de instalar) en Minikube, Kind u otro clúster compatible.
- `kubectl`, Helm 3, OpenSSL y `curl`.
- Docker no es necesario: el backend de demostración utiliza `hashicorp/http-echo`.
- Los comandos con sintaxis Bash se ejecutan en Linux/macOS, WSL o Git Bash. Adapta la asignación de variables si usas PowerShell.

## 🚀 Pasos del laboratorio

### Paso 1: Instalar Envoy Gateway

El chart instala Gateway API CRD y Envoy Gateway. La versión `v1.9.3` coincide con la guía oficial consultada; su matriz de compatibilidad indica Kubernetes `v1.33`–`v1.36`. Si tu clúster queda fuera de ese rango, elige una versión de Envoy Gateway compatible según la matriz, en vez de forzar la instalación.

```bash
helm install eg oci://docker.io/envoyproxy/gateway-helm \
  --version v1.9.3 \
  --namespace envoy-gateway-system \
  --create-namespace

kubectl wait --timeout=5m \
  -n envoy-gateway-system \
  deployment/envoy-gateway \
  --for=condition=Available

kubectl get crd gateways.gateway.networking.k8s.io
kubectl get pods -n envoy-gateway-system
```

**Esperado:** El controlador está disponible y existe la CRD `Gateway`.

### Paso 2: Crear namespace y backend de demostración

Guarda como `payment-demo.yaml`:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: production
---
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
      automountServiceAccountToken: false
      containers:
        - name: payment-service
          image: hashicorp/http-echo:1.0.0
          args:
            - "-listen=:8080"
            - "-text={\"service\":\"payment-service\",\"status\":\"UP\"}"
          ports:
            - name: http
              containerPort: 8080
          livenessProbe:
            tcpSocket:
              port: http
            periodSeconds: 10
          readinessProbe:
            tcpSocket:
              port: http
            periodSeconds: 5
          resources:
            requests:
              cpu: 50m
              memory: 32Mi
            limits:
              cpu: 250m
              memory: 64Mi
---
apiVersion: v1
kind: Service
metadata:
  name: payment-service
  namespace: production
spec:
  type: ClusterIP
  selector:
    app: payment-service
  ports:
    - name: http
      port: 80
      targetPort: http
```

Aplica y espera a que el backend esté listo:

```bash
kubectl apply -f payment-demo.yaml
kubectl rollout status deployment/payment-service -n production --timeout=120s
kubectl get pods,svc -n production
```

### Paso 3: Crear certificado de prueba y Secret TLS

El certificado incluye `subjectAltName`, que es lo que usan los clientes modernos para validar el hostname.

```bash
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout checkout.key \
  -out checkout.crt \
  -subj "/CN=checkout.local/O=E-CommercePlatform" \
  -addext "subjectAltName=DNS:checkout.local"

kubectl create secret tls checkout-tls-secret \
  --key checkout.key \
  --cert checkout.crt \
  --namespace production

kubectl describe secret checkout-tls-secret -n production
```

Mantén `checkout.key` local y no lo subas al repositorio. El certificado autofirmado sirve para el laboratorio, no como identidad confiable de producción.

### Paso 4: Configurar Gateway, HTTPS y rutas

Guarda como `checkout-gateway.yaml`:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: eg
spec:
  controllerName: gateway.envoyproxy.io/gatewayclass-controller
---
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: checkout-gateway
  namespace: production
spec:
  gatewayClassName: eg
  listeners:
    - name: http
      protocol: HTTP
      port: 80
      hostname: checkout.local
      allowedRoutes:
        namespaces:
          from: Same
    - name: https
      protocol: HTTPS
      port: 443
      hostname: checkout.local
      tls:
        mode: Terminate
        certificateRefs:
          - kind: Secret
            name: checkout-tls-secret
      allowedRoutes:
        namespaces:
          from: Same
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: checkout-http-redirect
  namespace: production
spec:
  parentRefs:
    - name: checkout-gateway
      sectionName: http
  hostnames:
    - checkout.local
  rules:
    - filters:
        - type: RequestRedirect
          requestRedirect:
            scheme: https
            statusCode: 301
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: checkout-payment
  namespace: production
spec:
  parentRefs:
    - name: checkout-gateway
      sectionName: https
  hostnames:
    - checkout.local
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - name: payment-service
          port: 80
```

Aplica los recursos y revisa sus condiciones:

```bash
kubectl apply -f checkout-gateway.yaml
kubectl get gatewayclass eg
kubectl get gateway,httproute -n production
kubectl describe gateway checkout-gateway -n production
kubectl describe httproute checkout-payment -n production
```

**Esperado:** `Gateway` y `HTTPRoute` muestran condiciones aceptadas y programadas. Si no es así, revisa `kubectl describe` antes de continuar.

### Paso 5: Probar HTTP y HTTPS en un clúster local

Obtén el Service del proxy de datos que Envoy Gateway creó para el Gateway:

```bash
ENVOY_SERVICE=$(kubectl get svc -n envoy-gateway-system \
  -l gateway.envoyproxy.io/owning-gateway-namespace=production,gateway.envoyproxy.io/owning-gateway-name=checkout-gateway \
  -o jsonpath='{.items[0].metadata.name}')
echo "$ENVOY_SERVICE"
```

En una terminal, reenvía los puertos:

```bash
kubectl port-forward -n envoy-gateway-system "service/$ENVOY_SERVICE" 8443:443 8080:80
```

En otra terminal, prueba HTTPS. `--cacert` confía explícitamente en el certificado autofirmado del ejercicio; no desactiva la validación TLS.

```bash
curl --cacert checkout.crt \
  --resolve checkout.local:8443:127.0.0.1 \
  -i https://checkout.local:8443/v1/payment
```

La respuesta debe incluir el texto JSON estático configurado en el contenedor. Verifica también la redirección HTTP:

```bash
curl --resolve checkout.local:8080:127.0.0.1 \
  -i "http://checkout.local:8080/v1/payment"
```

**Esperado:** HTTPS devuelve una respuesta de la aplicación y HTTP devuelve una redirección a HTTPS. No se presupone que Envoy asigne una dirección externa en Minikube o Kind; el `port-forward` es la vía local de prueba.

## 🔍 Troubleshooting

- **El chart no se instala o la versión de Kubernetes no es compatible:** consulta la matriz de compatibilidad de Envoy Gateway y elige una combinación soportada; no instales CRD de Gateway API de versiones distintas encima del chart.
- **El Gateway no está programado:** comprueba que `GatewayClass` tiene el `controllerName` correcto y revisa condiciones/eventos de `Gateway` y `HTTPRoute`.
- **El listener HTTPS no acepta el Secret:** confirma que `checkout-tls-secret` está en `production`, que es tipo `kubernetes.io/tls` y que `checkout.local` figura en el SAN.
- **No aparece el Service de proxy:** espera a que el Gateway se programe; confirma namespace y nombre con `kubectl get gateway -A` y busca el Service generado en `envoy-gateway-system`.
- **La solicitud no llega al backend:** confirma que el Deployment está listo y que el Service tiene endpoints (`kubectl get endpointslice -n production`).
- **Curl no confía en el certificado:** utiliza `--cacert checkout.crt`. Evita `-k` fuera de pruebas temporales porque omite la validación del certificado.

## 📊 Evidencia y reflexión

Documenta:

1. `kubectl get gatewayclass,gateway,httproute -n production` y las condiciones `Accepted`/`Programmed`.
2. `kubectl get svc -n production payment-service` y `kubectl get endpointslice -n production`.
3. La respuesta HTTPS validada con `--cacert` y el status de redirección HTTP.
4. ¿Qué termina TLS en esta práctica? ¿Qué cambios se necesitan para cifrar o autenticar también el tramo Gateway–backend?
5. ¿Qué describe `Ingress` y qué responsabilidades asume un controlador? ¿Qué ventajas y diferencias ofrece Gateway API?

## 🔗 Continuidad

El Laboratorio 3.2 añade `NetworkPolicy`. Antes de permitir entrada a `payment-service`, identifica el namespace y las etiquetas de los **Pods proxy de datos** de Envoy Gateway; no uses las etiquetas del controlador de control plane por suposición.

## 📚 Fuentes primarias

- Envoy Gateway. _Quickstart_ e instalación oficial. <https://gateway.envoyproxy.io/docs/tasks/quickstart/>
- Envoy Gateway. _Compatibility Matrix_. <https://gateway.envoyproxy.io/news/releases/matrix/>
- Envoy Gateway. _TLS Termination_. <https://gateway.envoyproxy.io/docs/tasks/security/tls-termination/>
- Kubernetes SIG Network. _Gateway API: Introduction_. <https://gateway-api.sigs.k8s.io/guides/getting-started/introduction/>
- Kubernetes Authors. _Ingress_. <https://kubernetes.io/docs/concepts/services-networking/ingress/>
- Kubernetes Authors. _TLS Secrets_. <https://kubernetes.io/docs/concepts/configuration/secret/#tls-secrets>
- Kubernetes SIG Network. _Ingress NGINX Retirement_. <https://kubernetes.io/blog/2025/11/11/ingress-nginx-retirement/>
- HashiCorp. _http-echo Dockerfile_ (distroless image). <https://github.com/hashicorp/http-echo/blob/master/Dockerfile>
