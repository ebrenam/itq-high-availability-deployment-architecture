# **Laboratorio 3.1:** Exposición Segura con Ingress + TLS

Desplegar payment-service con Ingress Controller y terminación TLS/SSL para acceso seguro desde el exterior del clúster.

---

## 🎯 Objetivo

Configurar un Ingress Controller NGINX y exponer `payment-service` mediante un certificado SSL/TLS autofirmado, garantizando que todo el tráfico externo esté encriptado y utilizando dominios estructurados (`checkout.local`).

---

## 📋 Requisitos Previos

- **Clúster Kubernetes:** 1.28+ (Minikube, Kind o k3s)
- **Herramientas instaladas:**
  - `kubectl` v1.28+
  - `helm` v3.12+
  - `openssl`
  - `curl`
- **Namespace:** `production` (será creado en el laboratorio)
- **Servicios heredados:** catalog-service, inventory-service funcionando

---

## 🚀 Punto de Partida

Usamos `proyecto-base-unidad-03` que incluye:
- ✅ catalog-service desplegado
- ✅ inventory-service desplegado
- ✅ payment-service listo para exponer

---

## 📝 Pasos del Laboratorio

### Paso 1: Instalar NGINX Ingress Controller

#### Linux y macOS

```bash
# 1. Agregar repositorio Helm de NGINX
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

# 2. Instalar Ingress Controller
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.type=ClusterIP

# 3. Verificar instalación
kubectl get pods -n ingress-nginx
kubectl get svc -n ingress-nginx
```

#### Windows (PowerShell)

```powershell
# 1. Agregar repositorio Helm
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

# 2. Instalar Ingress Controller
helm install ingress-nginx ingress-nginx/ingress-nginx `
  --namespace ingress-nginx `
  --create-namespace `
  --set controller.service.type=ClusterIP

# 3. Verificar
kubectl get pods -n ingress-nginx
kubectl get svc -n ingress-nginx
```

**Esperado:** Pod `ingress-nginx-controller-xxx` en estado `Running`.

---

### Paso 2: Generar Certificado SSL/TLS Autofirmado

#### Linux y macOS

```bash
# Crear certificado autofirmado válido por 365 días
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout checkout.key \
  -out checkout.crt \
  -subj "/CN=checkout.local/O=E-CommercePlatform" \
  -addext "subjectAltName=DNS:checkout.local"

# Verificar archivos creados
ls -la checkout.*
```

#### Windows (PowerShell)

```powershell
# Usando OpenSSL en Windows (si está instalado)
openssl req -x509 -nodes -days 365 -newkey rsa:2048 `
  -keyout checkout.key `
  -out checkout.crt `
  -subj "/CN=checkout.local/O=E-CommercePlatform" `
  -addext "subjectAltName=DNS:checkout.local"

# Verificar
Get-ChildItem checkout.*
```

**Esperado:** Archivos `checkout.crt` y `checkout.key` en el directorio actual.

---

### Paso 3: Crear Secret de TLS en Kubernetes

#### Linux, macOS y Windows

```bash
# Crear namespace
kubectl create namespace production --dry-run=client -o yaml | kubectl apply -f -

# Crear secret TLS
kubectl create secret tls checkout-tls-secret \
  --key checkout.key \
  --cert checkout.crt \
  -n production

# Verificar
kubectl get secret -n production
kubectl describe secret checkout-tls-secret -n production
```

**Esperado:** Secret tipo `kubernetes.io/tls` visible en el namespace `production`.

---

### Paso 4: Desplegar payment-service con Ingress

Crea el archivo `ingress-payment-tls.yaml`:

```yaml
---
# Deployment de payment-service
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
      containers:
      - name: payment-service
        image: ebrena/payment-service:1.0.0
        imagePullPolicy: Always
        ports:
        - containerPort: 8080
          name: http
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

---
# Service: ClusterIP para comunicación interna
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

---
# Ingress con TLS
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: checkout-ingress
  namespace: production
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
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
              number: 80
```

Aplica el manifiesto:

```bash
# Linux y macOS
kubectl apply -f ingress-payment-tls.yaml

# Windows PowerShell
kubectl apply -f ingress-payment-tls.yaml
```

Verifica:

```bash
kubectl get ingress -n production
kubectl get pods -n production
kubectl get svc -n production
```

**Esperado:** 
- Ingress `checkout-ingress` con hosts `checkout.local`
- Pods de payment-service en estado `Running` (2 réplicas)
- Service `payment-service` tipo ClusterIP

---

### Paso 5: Validar Acceso con TLS

#### Opción A: Usando port-forward (Recomendado)

Terminal 1 - Exponer el Ingress Controller:

```bash
kubectl port-forward -n ingress-nginx svc/ingress-nginx-controller 8443:443
```

Terminal 2 - Realizar prueba:

```bash
# Linux y macOS
curl -k -v --resolve checkout.local:8443:127.0.0.1 https://checkout.local:8443/v1/payment

# Windows PowerShell
curl -k -v --resolve checkout.local:8443:127.0.0.1 https://checkout.local:8443/v1/payment
```

**Esperado:**
```
* SSL connection made
* Server certificate:
  * subject: CN=checkout.local; O=E-CommercePlatform
  * issuer: CN=checkout.local; O=E-CommercePlatform
  * SSL certificate verify result: self signed certificate
* TLS 1.3
> GET /v1/payment HTTP/1.1
< HTTP/1.1 200 OK
< Content-Type: application/json
{
  "service": "payment-service",
  "status": "UP",
  "timestamp": 1634567890000,
  "version": "1.0.0"
}
```

#### Opción B: Desde dentro del cluster

```bash
# Ejecutar curl dentro de un Pod
kubectl exec -it -n production deployment/payment-service -- sh

# Dentro del Pod:
curl http://checkout-ingress.production.svc.cluster.local/v1/payment
# O verificar endpoint de health
curl http://localhost:8080/q/health
```

---

## 🔍 Guía de Troubleshooting

### Problema 1: Ingress se queda en estado `<pending>` o sin IP

**Síntomas:** `kubectl get ingress -n production` muestra `<none>` en ADDRESS

**Causas posibles:**
- Ingress Controller no está instalado
- Ingress Controller está en estado Error

**Solución:**

```bash
# 1. Verificar que Ingress Controller está corriendo
kubectl get pods -n ingress-nginx

# 2. Ver logs del controller
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller

# 3. Reinstalar si es necesario
helm uninstall ingress-nginx -n ingress-nginx
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.type=ClusterIP
```

---

### Problema 2: Error "SSL: CERTIFICATE_VERIFY_FAILED" o "peer certificate cannot be authenticated"

**Síntomas:** curl falla verificando el certificado autofirmado

**Solución:** Usar flag `-k` en curl para ignorar verificación (solo para pruebas):

```bash
curl -k https://checkout.local:8443/v1/payment
```

---

### Problema 3: Pods de payment-service en estado CrashLoopBackOff

**Síntomas:** 
```
STATUS: CrashLoopBackOff
```

**Causas posibles:**
- Imagen Docker no existe o es inaccesible
- Puerto 8080 ya está en uso
- Falta de memoria o CPU

**Solución:**

```bash
# Ver logs del pod
kubectl logs -n production pod/payment-service-xxx

# Describir pod para más detalles
kubectl describe pod -n production pod/payment-service-xxx

# Verificar imagen (si usas Docker local en Minikube)
minikube image load ebrena/payment-service:1.0.0

# Redeployar
kubectl rollout restart deployment/payment-service -n production
```

---

### Problema 4: HTTP 502 Bad Gateway desde el Ingress

**Síntomas:** 
```
curl: (56) Received HTTP code 502 from proxy
```

**Causas posibles:**
- Pods no están en estado Running
- readinessProbe está fallando
- Service no tiene endpoints

**Solución:**

```bash
# Verificar estado de pods
kubectl get pods -n production -o wide

# Verificar readiness
kubectl describe pod -n production pod/payment-service-xxx | grep -A 5 "Ready"

# Verificar que el service tiene endpoints
kubectl get endpoints -n production payment-service

# Ver logs del pod
kubectl logs -n production pod/payment-service-xxx
```

---

## 📊 Evidencia / Validación

Para completar este laboratorio, debes documentar:

### 1. Ingress Controller Instalado
```bash
kubectl get svc -n ingress-nginx
kubectl get pods -n ingress-nginx
```
**Screenshot esperado:** Pod en estado `Running`

### 2. Certificado TLS Creado
```bash
openssl x509 -in checkout.crt -text -noout
```
**Screenshot esperado:** Certificado con CN=checkout.local, válido por 365 días

### 3. Secret Kubernetes
```bash
kubectl get secret -n production checkout-tls-secret -o yaml
```
**Screenshot esperado:** Secret con `tls.crt` y `tls.key`

### 4. Ingress Operativo
```bash
kubectl get ingress -n production -o wide
```
**Screenshot esperado:** Ingress `checkout-ingress` con host `checkout.local` y TLS activo

### 5. Acceso HTTPS Funcional
```bash
curl -k -v --resolve checkout.local:8443:127.0.0.1 https://checkout.local:8443/v1/payment
```
**Screenshot esperado:** 
- HTTP/2 o HTTP/1.1 conexión TLS exitosa
- JSON de respuesta con status `UP`
- Certificado autofirmado verificado (o ignorado con `-k`)

---

## 🎓 Reflexión Final

**Preguntas para reflexionar:**

1. ¿Por qué es importante terminar TLS en el Ingress en lugar del Pod?
   - Respuesta: Centraliza la gestión de certificados, descarga computacional del Pod, y aplica política de seguridad en un solo lugar.

2. ¿Qué diferencia hay entre `nginx.ingress.kubernetes.io/ssl-redirect` y `nginx.ingress.kubernetes.io/force-ssl-redirect`?
   - Respuesta: `ssl-redirect` es más permisivo (permite algunos paths HTTP), mientras `force-ssl-redirect` fuerza todos los paths a HTTPS.

3. ¿Cuál es la ventaja de usar un certificado autofirmado vs. Let's Encrypt?
   - Respuesta: Autofirmado es instantáneo para dev/test, pero Let's Encrypt es gratuito y trusted para producción.

---

## 🔗 Continuidad

**Próximo paso (Laboratorio 3.2):**
- Implementar NetworkPolicies para aislar tráfico entre servicios
- Configurar DENY All default y permitir solo rutas necesarias
- Validar que solo Ingress puede alcanzar payment-service

**Relación con unidades anteriores:**
- U2.3 configuró HPA; aquí aseguramos el punto de entrada
- U1.3 probó disponibilidad; aquí agregamos seguridad

---

## 📚 Recursos Adicionales

- [NGINX Ingress Controller - Documentación oficial](https://kubernetes.github.io/ingress-nginx/)
- [Kubernetes TLS Secrets](https://kubernetes.io/docs/concepts/configuration/secret/#tls-secrets)
- [RFC 5246 - TLS 1.2](https://tools.ietf.org/html/rfc5246)
- [OWASP Transport Layer Protection](https://cheatsheetseries.owasp.org/cheatsheets/Transport_Layer_Protection_Cheat_Sheet.html)

---

**Laboratorio 3.1 - Versión:** 1.0  
**Última actualización:** 2026-10-15  
**Estado:** ✅ Listo para docencia
