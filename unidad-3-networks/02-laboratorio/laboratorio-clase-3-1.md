# Laboratorio de la clase 3.1: Integración de Microservicios y Exposición con Gateway API

## Objetivo del laboratorio y escenario real

**El escenario:** Trabajas como Cloud Engineer en Cortex Retail. En Unidad 2 desplegaste `catalog-service` e `inventory-service` en Kubernetes. Ahora necesitas:
1. Crear un nuevo microservicio `payment-service` que orquesta pagos
2. Implementar llamadas HTTP reales entre servicios (payment → catalog, payment → inventory)
3. Exponer `payment-service` públicamente con TLS mediante Gateway API
4. Validar que la arquitectura e-commerce funciona de extremo a extremo

**El objetivo:** Construir y desplegar `payment-service` v1.0.0 que se comunica con servicios heredados, exponer con seguridad TLS, y demostrar que los 3 servicios funcionan coordinados en Kubernetes.

**Salida esperada:** Tres microservicios (catalog, inventory, payment) ejecutándose en Minikube, comunicándose internamente, con payment accesible externamente vía HTTPS mediante Gateway API.

---

## Requisitos previos

- Minikube v1.32+ o Kind con Kubernetes 1.28+ instalado y ejecutándose
- Maven 3.9+ y JDK 21+
- Docker Desktop o Podman (para compilar y publicar imágenes)
- Docker Hub account con credenciales configuradas (`docker login`)
- `kubectl`, Helm 3, OpenSSL y `curl`
- Acceso a los directorios de U2: `proyecto-base-unidad-02/catalog-service` e `inventory-service`
- Los comandos con sintaxis Bash se ejecutan en Linux/macOS, WSL o Git Bash

## Notas pedagógicas previas

**Versiones en este laboratorio:**
- `catalog-service:1.0.0` (sin cambios de U2)
- `inventory-service:1.2.0` (upgrade con POST /v1/inventory/reserve)
- `payment-service:1.0.0` (NUEVO)

**Qué hace este laboratorio:** Construye un flujo realista de e-commerce donde `payment-service` orquesta llamadas HTTP sincrónicas a otros servicios, demostrando comunicación inter-pod en Kubernetes. Es la base para Laboratorio 3.2 (NetworkPolicy).

---

## Pasos del laboratorio

### Paso 1: Preparar la carpeta de trabajo

**Qué hace:** Crea estructura de directorios limpia y descarga el código base de U2.

**Por qué:** Necesitamos versiones consistentes de catalog e inventory antes de crear payment.

![linux](images/linux.png) **Linux/macOS:**

```bash
# Colócate en el directorio del proyecto base de U3
cd unidad-3-networks/02-laboratorio/proyecto-base-unidad-03

# Verifica que existen las carpetas de servicios heredados
ls -la catalog-service/ inventory-service/

# Confirma versiones actuales en pom.xml
grep "<version>" catalog-service/pom.xml | head -1
grep "<version>" inventory-service/pom.xml | head -1
```

![win](images/windows.png) **Windows (PowerShell):**

```powershell
cd unidad-3-networks/02-laboratorio/proyecto-base-unidad-03

ls catalog-service/, inventory-service/

Select-String "<version>" catalog-service/pom.xml | Select-Object -First 1
Select-String "<version>" inventory-service/pom.xml | Select-Object -First 1
```

**Qué observar:** Ambas carpetas existen con archivos pom.xml legibles. Las versiones deben ser 1.0.0 (catalog) y 1.1.0 (inventory).

---

### Paso 2: Actualizar inventory-service a v1.2.0 - Modificar pom.xml

**Qué hace:** Cambia la versión y prepara para agregar nueva funcionalidad.

**Por qué:** Semantic versioning: MINOR bump para endpoint nuevo backward-compatible.

![linux](images/linux.png) **Linux/macOS:**

```bash
# Abre el archivo pom.xml en tu editor
nano inventory-service/pom.xml

# O, directamente con sed (reemplaza 1.0.0-SNAPSHOT por 1.2.0):
sed -i.bak 's/<version>1\.0\.0-SNAPSHOT<\/version>/<version>1.2.0<\/version>/' inventory-service/pom.xml

# Verifica el cambio
grep "<version>" inventory-service/pom.xml | head -1
```

![win](images/windows.png) **Windows (PowerShell):**

```powershell
# Abre en editor y modifica manualmente, o:
(Get-Content inventory-service/pom.xml) -replace '1\.0\.0-SNAPSHOT', '1.2.0' | Set-Content inventory-service/pom.xml

# Verifica
Select-String "<version>" inventory-service/pom.xml | Select-Object -First 1
```

**Qué observar:** El pom.xml ahora muestra `<version>1.2.0</version>`.

**Nota:** No compilamos aún; primero agregamos el código.

---

### Paso 3: Agregar endpoint POST /v1/inventory/reserve a InventoryResource

**Qué hace:** Extiende InventoryResource con un nuevo endpoint para reservar inventario.

**Por qué:** payment-service necesitará reservar stock antes de procesar pagos.

**Abrir archivo y ver contenido actual:**

```bash
cat inventory-service/src/main/java/com/ecom/inventory/InventoryResource.java
```

**Agregar método a InventoryResource:**

Abre el archivo `inventory-service/src/main/java/com/ecom/inventory/InventoryResource.java` en tu editor (VS Code, Vi, nano). 

Ubica el cierre de la clase (antes de la última `}`). Agrega el siguiente código:

```java

    @POST
    @Path("/reserve")
    @Consumes(MediaType.APPLICATION_JSON)
    @Produces(MediaType.APPLICATION_JSON)
    public ReservationResponse reserveInventory(ReservationRequest request) {
        String transactionId = UUID.randomUUID().toString().substring(0, 8).toUpperCase();
        
        // Simulamos lógica de reserva (en un caso real, consultaría DB)
        boolean isReserved = request.quantity() > 0 && request.productId() != null;
        
        return new ReservationResponse(
            request.productId(),
            request.quantity(),
            isReserved ? "RESERVED" : "FAILED",
            Instant.now()
        );
    }

    // Clases de request/response
    public record ReservationRequest(String productId, int quantity) {}
    
    public record ReservationResponse(
        String productId,
        int reservedQuantity,
        String status,
        Instant timestamp
    ) {}
```

> **Nota:** Copia el código anterior, pégalo en el archivo antes del cierre de la clase. Guarda con Ctrl+S (o Cmd+S en macOS).

**Qué observar:** El archivo ahora tiene dos métodos: `@GET /inventory` (heredado) y `@POST /reserve` (nuevo).

**Nota pedagógica:** Observe que el método retorna un `ReservationResponse` con timestamp. Esto es importante para auditoría en sistemas de pagos reales.

---

### Paso 4: Compilar y publicar inventory-service v1.2.0 a Docker Hub

**Qué hace:** Compila el JAR, crea imagen Docker y la publica con etiqueta v1.2.0.

**Por qué:** payment-service necesitará llamar a esta versión con el nuevo endpoint.

![linux](images/linux.png) **Linux/macOS:**

```bash
cd inventory-service

# Compilar (skipping tests para rapidez)
mvn clean package -DskipTests

# Verificar que se creó el JAR
ls -la target/quarkus-app/

# Construir imagen Docker
docker build -t <tu_usuario>/inventory-service:1.2.0 .

# Publicar a Docker Hub
docker push <tu_usuario>/inventory-service:1.2.0

# Verificar en Docker Hub
docker inspect <tu_usuario>/inventory-service:1.2.0

cd ..
```

![win](images/windows.png) **Windows (PowerShell):**

```powershell
cd inventory-service

mvn clean package -DskipTests

ls target/quarkus-app/

docker build -t <tu_usuario>/inventory-service:1.2.0 .

docker push <tu_usuario>/inventory-service:1.2.0

docker inspect <tu_usuario>/inventory-service:1.2.0

cd ..
```

**Qué observar:** `docker push` debe completarse sin errores. En Docker Hub, la imagen aparece con tags `latest` y `1.2.0`.

**Nota:** Reemplaza `<tu_usuario>` con tu usuario real de Docker Hub (ej: `jdoe`).

---

### Paso 5: Crear estructura Maven para payment-service

**Qué hace:** Genera nuevo proyecto Quarkus con pom.xml y estructura estándar.

**Por qué:** payment-service es completamente nuevo; usamos Maven archetype para scaffolding consistente.

![linux](images/linux.png) **Linux/macOS:**

```bash
cd proyecto-base-unidad-03

# Generar proyecto con Maven
mvn io.quarkus.platform:quarkus-maven-plugin:3.40.1.1:create \
  -DprojectGroupId=com.ecom \
  -DprojectArtifactId=payment-service \
  -Dextensions="rest-jackson,smallrye-health,smallrye-fault-tolerance,rest-client-jackson"

# Ingresa al directorio nuevo
cd payment-service

# Verifica estructura
ls -la
cat pom.xml | grep "<version>" | head -2
```

![win](images/windows.png) **Windows (PowerShell):**

```powershell
cd proyecto-base-unidad-03

mvn io.quarkus.platform:quarkus-maven-plugin:3.40.1.1:create `
  -DprojectGroupId=com.ecom `
  -DprojectArtifactId=payment-service `
  -Dextensions="rest-jackson,smallrye-health,smallrye-fault-tolerance,rest-client-jackson"

cd payment-service

ls

Select-String "<version>" pom.xml | Select-Object -First 2
```

**Qué observar:** Se crea directorio `payment-service/` con:
- `pom.xml` (con version `999-SNAPSHOT`)
- `src/main/java/com/ecom/payment/`
- `Dockerfile`
- `mvnw`, `mvnw.cmd`

---

### Paso 6: Actualizar pom.xml de payment-service a versión 1.0.0

**Qué hace:** Cambia version de SNAPSHOT a 1.0.0 de producción.

**Por qué:** No publicamos SNAPSHOT a Docker Hub; usamos versiones semánticas estables.

![linux](images/linux.png) **Linux/macOS:**

```bash
# Reemplaza version en payment-service/pom.xml
sed -i.bak 's/<version>999-SNAPSHOT<\/version>/<version>1.0.0<\/version>/' pom.xml

# Verifica
grep "<version>" pom.xml | head -1
```

![win](images/windows.png) **Windows (PowerShell):**

```powershell
(Get-Content pom.xml) -replace '999-SNAPSHOT', '1.0.0' | Set-Content pom.xml

Select-String "<version>" pom.xml | Select-Object -First 1
```

**Qué observar:** pom.xml ahora muestra `<version>1.0.0</version>`.

---

### Paso 7: Crear PaymentResource (REST endpoint)

**Qué hace:** Define el endpoint HTTP `/v1/payments` que recibe solicitudes de pago.

**Por qué:** Es la "puerta de entrada" de payment-service; orquesta las llamadas a otros servicios.

**Crear archivo `src/main/java/com/ecom/payment/PaymentResource.java`:**

Genera el archivo con el siguiente contenido:

```java
package com.ecom.payment;

import jakarta.inject.Inject;
import jakarta.ws.rs.*;
import jakarta.ws.rs.core.MediaType;
import java.time.Instant;
import java.util.UUID;

@Path("/v1/payments")
@Consumes(MediaType.APPLICATION_JSON)
@Produces(MediaType.APPLICATION_JSON)
public class PaymentResource {

    @Inject
    PaymentService paymentService;

    @POST
    public PaymentResponse processPayment(PaymentRequest request) {
        try {
            return paymentService.processPayment(request);
        } catch (Exception e) {
            return new PaymentResponse(
                UUID.randomUUID().toString().substring(0, 12),
                "FAILED",
                request.productId(),
                request.quantity(),
                request.amount(),
                e.getMessage(),
                Instant.now()
            );
        }
    }

    public record PaymentRequest(String productId, int quantity, double amount) {}

    public record PaymentResponse(
        String transactionId,
        String status,
        String productId,
        int quantity,
        double amount,
        String message,
        Instant timestamp
    ) {}
}
```

**Qué observar:** Archivo compilable sin errores. Usa `@Path("/v1/payments")` e inyecta `PaymentService`.

**Nota pedagógica:** Observe que el POST devuelve transactionId único (UUID truncado). En producción, esto se guardería en BD.

---

### Paso 8: Crear PaymentService (orquestación con MicroProfile FaultTolerance)

**Qué hace:** Orquesta la lógica: valida producto, reserva inventario, simula pago.

**Por qué:** Demuestra patrones reales: @Timeout, @Retry, y decisiones de negocio.

**Crear archivo `src/main/java/com/ecom/payment/PaymentService.java`:**

Genera el archivo con el siguiente contenido:

**Qué observar:** La clase usa `@Timeout` para timeout de 3 segundos total, con `@Retry` para reintentos en llamadas a clientes. Esto es resilience real.

**Nota pedagógica:** El 90% de éxito en pagos es para simular "mundo real" donde no todo es éxito. En producción, se validaría con gateway real.

---

### Paso 9: Crear CatalogClient (cliente HTTP a catalog-service)

**Qué hace:** Cliente JAX-RS que llama GET /v1/products/{id} en catalog-service.

**Por qué:** payment-service necesita validar que el producto existe antes de procesar pago.

**Crear archivo `src/main/java/com/ecom/payment/CatalogClient.java`:**

Genera el archivo con el siguiente contenido:

**Qué observar:** URL es `http://catalog-service:80`. Este es nombre DNS interno de Kubernetes; resuelve a la IP del Service.

**Nota pedagógica:** `catalog-service:80` funciona porque Kubernetes CoreDNS resuelve automáticamente nombres de Service. No usamos IP directa.

---

### Paso 10: Crear InventoryClient (cliente HTTP a inventory-service)

**Qué hace:** Cliente JAX-RS que POST a /v1/inventory/reserve en inventory-service.

**Por qué:** payment-service debe reservar stock antes de procesar pago.

**Crear archivo `src/main/java/com/ecom/payment/InventoryClient.java`:**

Genera el archivo con el siguiente contenido:

**Qué observar:** URL es `http://inventory-service:80` (DNS interno). POST envía JSON con productId y quantity.

**Nota pedagógica:** Ambos clientes usan el mismo patrón: construir URL con DNS del servicio, enviar request JSON, parsear respuesta.

---

### Paso 11: Configurar application.properties

**Qué hace:** Define propiedades de configuración de Quarkus para payment-service.

**Por qué:** Ports, health endpoints, y nombre de aplicación.

**Crear o editar archivo `src/main/resources/application.properties`:**

Copia el siguiente contenido:

```properties
quarkus.http.port=8080
quarkus.http.host=0.0.0.0
quarkus.application.name=payment-service
quarkus.application.version=1.0.0
quarkus.smallrye-health.root-path=/health
```

**Qué observar:** Archivo está creado con settings correctos.

---

### Paso 12: Compilar payment-service y publicar a Docker Hub

**Qué hace:** Compila JAR, crea imagen Docker, publica como v1.0.0.

**Por qué:** Es la versión lista para desplegar en Kubernetes.

![linux](images/linux.png) **Linux/macOS:**

```bash
# Desde directorio payment-service/
mvn clean package -DskipTests

# Verifica JAR
ls -la target/quarkus-app/

# Construir imagen
docker build -t <tu_usuario>/payment-service:1.0.0 .

# Publicar
docker push <tu_usuario>/payment-service:1.0.0

# Verifica en Docker Hub
curl -s "https://hub.docker.com/v2/repositories/<tu_usuario>/payment-service/tags" | grep "1.0.0"

# Volver al directorio proyecto
cd ..
```

![win](images/windows.png) **Windows (PowerShell):**

```powershell
mvn clean package -DskipTests

ls target/quarkus-app/

docker build -t <tu_usuario>/payment-service:1.0.0 .

docker push <tu_usuario>/payment-service:1.0.0

# Verifica (requiere curl)
curl -s "https://hub.docker.com/v2/repositories/<tu_usuario>/payment-service/tags"

cd ..
```

**Qué observar:** `docker push` completa exitosamente. Imagen aparece en Docker Hub.

**Nota:** Reemplaza `<tu_usuario>` con tu usuario real de Docker Hub.

---

### Paso 13: Crear manifestos Kubernetes para payment-service

**Qué hace:** Define Deployment y Service de payment-service en K8s.

**Por qué:** Necesitamos describir cómo correr payment-service en el clúster.

**Crear directorio `payment-service/k8s/`:**

```bash
mkdir -p payment-service/k8s
```

**Crear archivo `payment-service/k8s/01-deployment.yaml`:**

Genera el archivo con el siguiente contenido:

```yaml
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
    spec:
      containers:
        - name: payment-service
          image: <tu_usuario>/payment-service:1.0.0
          imagePullPolicy: Always
          ports:
            - name: http
              containerPort: 8080
          env:
            - name: QUARKUS_HTTP_PORT
              value: "8080"
          livenessProbe:
            httpGet:
              path: /health/live
              port: http
            initialDelaySeconds: 30
            periodSeconds: 10
            timeoutSeconds: 3
          readinessProbe:
            httpGet:
              path: /health/ready
              port: http
            initialDelaySeconds: 10
            periodSeconds: 5
            timeoutSeconds: 2
          startupProbe:
            httpGet:
              path: /health/startup
              port: http
            failureThreshold: 30
            periodSeconds: 2
          resources:
            requests:
              cpu: 100m
              memory: 256Mi
            limits:
              cpu: 500m
              memory: 512Mi
```

**Crear archivo `payment-service/k8s/02-service.yaml`:**

Genera el archivo con el siguiente contenido:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: payment-service
  namespace: production
  labels:
    app: payment-service
spec:
  type: ClusterIP
  selector:
    app: payment-service
  ports:
    - name: http
      port: 80
      targetPort: http
      protocol: TCP
```

**Qué observar:** Ambos archivos están creados. Nota que `imagePullPolicy: Always` fuerza pull de Docker Hub.

**Nota pedagógica:** `startupProbe` es importante para apps Java que tardan en iniciar. Da 60 segundos (30 reintentos x 2 segundos).

---

### Paso 14: Desplegar los 3 servicios en Kubernetes

**Qué hace:** Aplica manifiestos de catalog, inventory, y payment al clúster.

**Por qué:** Es el momento de ver los servicios corriendo juntos.

**Validación previa:**

```bash
# Verifica que tienes Minikube/Kind ejecutándose
kubectl cluster-info

# Verifica namespace production
kubectl get namespace production || kubectl create namespace production

# Verifica que los 3 servicios tienen manifiestos
find proyecto-base-unidad-03 -name "01-deployment.yaml" -o -name "02-service.yaml" | sort
```

![linux](images/linux.png) **Desplegar (Linux/macOS):**

```bash
cd proyecto-base-unidad-03

# Desplegar catalog-service (heredado de U2)
kubectl apply -f catalog-service/k8s/01-deployment.yaml
kubectl apply -f catalog-service/k8s/02-service.yaml

# Desplegar inventory-service v1.2.0
kubectl apply -f inventory-service/k8s/01-deployment.yaml
kubectl apply -f inventory-service/k8s/02-service.yaml

# Desplegar payment-service v1.0.0
kubectl apply -f payment-service/k8s/01-deployment.yaml
kubectl apply -f payment-service/k8s/02-service.yaml

# Espera a que los Pods estén Ready
kubectl rollout status deployment/catalog-service -n production --timeout=120s
kubectl rollout status deployment/inventory-service -n production --timeout=120s
kubectl rollout status deployment/payment-service -n production --timeout=120s

# Verifica estado
kubectl get pods -n production -o wide
kubectl get svc -n production
```

![win](images/windows.png) **Desplegar (Windows - PowerShell):**

```powershell
cd proyecto-base-unidad-03

kubectl apply -f catalog-service/k8s/01-deployment.yaml
kubectl apply -f catalog-service/k8s/02-service.yaml

kubectl apply -f inventory-service/k8s/01-deployment.yaml
kubectl apply -f inventory-service/k8s/02-service.yaml

kubectl apply -f payment-service/k8s/01-deployment.yaml
kubectl apply -f payment-service/k8s/02-service.yaml

kubectl rollout status deployment/catalog-service -n production --timeout=120s
kubectl rollout status deployment/inventory-service -n production --timeout=120s
kubectl rollout status deployment/payment-service -n production --timeout=120s

kubectl get pods -n production -o wide
kubectl get svc -n production
```

**Qué observar:** 
- Todos los Pods están en `Running` (2 replicas cada uno = 6 Pods totales)
- Los Services tienen ClusterIP asignadas
- `kubectl logs pod/<pod_name> -n production` muestra logs de Quarkus sin errores

**Nota pedagógica:** Los Pods pueden tardar 30-60 segundos en iniciar debido a `startupProbe`. Es normal.

---

### Paso 15: Probar comunicación inter-servicios (sin Gateway aún)

**Qué hace:** Verifica que payment-service puede alcanzar catalog e inventory internamente.

**Por qué:** Validar la arquitectura antes de exponerla externamente.

![linux](images/linux.png) **Linux/macOS:**

```bash
# Acceder a un Pod de payment-service
POD_NAME=$(kubectl get pods -n production -l app=payment-service -o jsonpath='{.items[0].metadata.name}')

# Prueba 1: Ver logs
kubectl logs $POD_NAME -n production -f

# Prueba 2: Hacer un curl interno desde otro Pod
kubectl exec -it $POD_NAME -n production -- curl -X POST http://payment-service:80/v1/payments \
  -H "Content-Type: application/json" \
  -d '{"productId":"PROD-001","quantity":1,"amount":19.99}' 

# Deberías ver respuesta JSON con transactionId y status (APPROVED o FAILED)
```

![win](images/windows.png) **Windows (PowerShell):**

```powershell
$POD_NAME = kubectl get pods -n production -l app=payment-service -o jsonpath='{.items[0].metadata.name}'

kubectl logs $POD_NAME -n production -f

kubectl exec -it $POD_NAME -n production -- curl -X POST http://payment-service:80/v1/payments `
  -H "Content-Type: application/json" `
  -d '{"productId":"PROD-001","quantity":1,"amount":19.99}'
```

**Qué observar:** La respuesta JSON contiene `transactionId` y `status` (APPROVED o FAILED aleatoriamente).

**Nota pedagógica:** Si falla con timeout, puede ser:
1. Pods aún no listo (espera más)
2. Imagen Docker no se descargó (verifica `kubectl describe pod`)
3. DNS no funciona (intenta con IP: `kubectl get svc -n production` y usa ClusterIP)

---

### Paso 16: Instalar Envoy Gateway y crear Gateway API

**Qué hace:** Instala Envoy Gateway Controller y recursos de Gateway API.

**Por qué:** Necesitamos exponerlo con TLS (HTTPS) para acceso externo.

![linux](images/linux.png) **Linux/macOS:**

```bash
# Agrega repo de Helm para Envoy
helm repo add envoy-ai https://envoyproxy.github.io/gateway-helm
helm repo update

# Instala Envoy Gateway v1.9.3 (compatible con K8s 1.28+)
helm install eg envoy-ai/gateway \
  --version v1.9.3 \
  --namespace envoy-gateway-system \
  --create-namespace

# Espera a que el controlador esté listo
kubectl wait --timeout=5m \
  -n envoy-gateway-system \
  deployment/envoy-gateway \
  --for=condition=Available

# Verifica instalación
kubectl get crd gateways.gateway.networking.k8s.io
kubectl get pods -n envoy-gateway-system
```

![win](images/windows.png) **Windows (PowerShell):**

```powershell
helm repo add envoy-ai https://envoyproxy.github.io/gateway-helm
helm repo update

helm install eg envoy-ai/gateway `
  --version v1.9.3 `
  --namespace envoy-gateway-system `
  --create-namespace

kubectl wait --timeout=5m `
  -n envoy-gateway-system `
  deployment/envoy-gateway `
  --for=condition=Available

kubectl get crd gateways.gateway.networking.k8s.io
kubectl get pods -n envoy-gateway-system
```

**Qué observar:** Se crean CRDs (`gateways.gateway.networking.k8s.io`, etc.) y Pod `envoy-gateway-xxxx` está en `Running`.

---

### Paso 17: Crear certificado TLS y configurar Gateway + HTTPRoute

**Qué hace:** Genera certificado autofirmado, lo monta en Secret K8s, y configura enrutamiento externo.

**Por qué:** payment-service debe estar accesible vía HTTPS externamente.

![linux](images/linux.png) **Generar certificado (Linux/macOS):**

```bash
cd proyecto-base-unidad-03

# Crear certificado autofirmado válido 365 días
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout payment.key \
  -out payment.crt \
  -subj "/CN=payment.local/O=Cortex" \
  -addext "subjectAltName=DNS:payment.local,DNS:localhost"

# Verifica certificado
openssl x509 -in payment.crt -text -noout | head -20

# Crea Secret de TLS en K8s
kubectl create secret tls payment-tls-secret \
  --cert=payment.crt \
  --key=payment.key \
  --namespace=production

# Verifica
kubectl get secret -n production
```

**Generar certificado (Windows - PowerShell):**

Si tienes OpenSSL en WSL o Git Bash:

```bash
# En Git Bash
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout payment.key \
  -out payment.crt \
  -subj "/CN=payment.local/O=Cortex" \
  -addext "subjectAltName=DNS:payment.local,DNS:localhost"

kubectl create secret tls payment-tls-secret \
  --cert=payment.crt \
  --key=payment.key \
  --namespace=production
```

**Crear archivo `payment-service/k8s/03-gateway.yaml`:**

Genera el archivo con el siguiente contenido:

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
  name: payment-gateway
  namespace: production
spec:
  gatewayClassName: eg
  listeners:
    - name: http
      protocol: HTTP
      port: 80
      hostname: payment.local
      allowedRoutes:
        namespaces:
          from: Same
    - name: https
      protocol: HTTPS
      port: 443
      hostname: payment.local
      tls:
        mode: Terminate
        certificateRefs:
          - kind: Secret
            name: payment-tls-secret
      allowedRoutes:
        namespaces:
          from: Same
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: payment-route
  namespace: production
spec:
  parentRefs:
    - name: payment-gateway
      sectionName: https
  hostnames:
    - payment.local
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /v1/payments
      backendRefs:
        - name: payment-service
          port: 80
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: payment-http-redirect
  namespace: production
spec:
  parentRefs:
    - name: payment-gateway
      sectionName: http
  hostnames:
    - payment.local
  rules:
    - filters:
        - type: RequestRedirect
          requestRedirect:
            scheme: https
            statusCode: 301
```

**Aplicar manifiestos:**

```bash
kubectl apply -f payment-service/k8s/03-gateway.yaml

kubectl get gatewayclass,gateway,httproute -n production
kubectl describe gateway payment-gateway -n production
```

**Qué observar:** 
- `GatewayClass` existe y tiene controller asignado
- `Gateway` muestra condiciones `Accepted: True` y `Programmed: True`
- `HTTPRoute` muestra `Accepted: True`

---

### Paso 18: Probar acceso externo con TLS

**Qué hace:** Accede a payment-service desde fuera del clúster via HTTPS usando Gateway.

**Por qué:** Validar que la exposición funciona end-to-end.

![linux](images/linux.png) **Linux/macOS:**

```bash
# Obtener nombre del Service de Envoy proxy (creado automáticamente por Gateway)
ENVOY_SERVICE=$(kubectl get svc -n envoy-gateway-system \
  -l gateway.envoyproxy.io/owning-gateway-namespace=production,gateway.envoyproxy.io/owning-gateway-name=payment-gateway \
  -o jsonpath='{.items[0].metadata.name}')

echo "Envoy Service: $ENVOY_SERVICE"

# En una terminal, reenviar puertos
kubectl port-forward -n envoy-gateway-system "service/$ENVOY_SERVICE" 8443:443 8080:80 &

# Esperar 2 segundos
sleep 2

# Probar HTTPS (con certificado autofirmado)
curl --cacert payment.crt \
  --resolve payment.local:8443:127.0.0.1 \
  -X POST https://payment.local:8443/v1/payments \
  -H "Content-Type: application/json" \
  -d '{"productId":"PROD-002","quantity":2,"amount":39.98}' \
  -v

# Probar redirección HTTP→HTTPS
curl --resolve payment.local:8080:127.0.0.1 \
  -i "http://payment.local:8080/v1/payments"

# Detener port-forward (encontrar PID)
# kill %1
```

![win](images/windows.png) **Windows (PowerShell):**

```powershell
$ENVOY_SERVICE = kubectl get svc -n envoy-gateway-system `
  -l gateway.envoyproxy.io/owning-gateway-namespace=production,gateway.envoyproxy.io/owning-gateway-name=payment-gateway `
  -o jsonpath='{.items[0].metadata.name}'

Write-Host "Envoy Service: $ENVOY_SERVICE"

# En PowerShell, start port-forward en background
Start-Process -NoNewWindow kubectl -ArgumentList "port-forward", "-n", "envoy-gateway-system", "service/$ENVOY_SERVICE", "8443:443", "8080:80"

# Esperar
Start-Sleep -Seconds 2

# Probar HTTPS
curl --cacert payment.crt `
  --resolve payment.local:8443:127.0.0.1 `
  -X POST https://payment.local:8443/v1/payments `
  -H "Content-Type: application/json" `
  -d '{\"productId\":\"PROD-002\",\"quantity\":2,\"amount\":39.98}' `
  -v

# Probar redirección
curl --resolve payment.local:8080:127.0.0.1 `
  -i "http://payment.local:8080/v1/payments"
```

**Qué observar:**
- Respuesta HTTPS contiene JSON: `{"transactionId":"...", "status":"APPROVED"/"FAILED", ...}`
- Respuesta HTTP contiene código `301` (redirección a HTTPS)
- Certificado se verifica correctamente con `--cacert`

**Nota pedagógica:** El `--cacert` es confianza explícita. NO usamos `-k` (insecuro) porque eso desactivaría validación TLS.

---

## Evidencia y reflexión

**Documenta estos resultados en tu portafolio:**

1. **Comandos clave ejecutados:**
   ```bash
   kubectl get pods,svc -n production
   kubectl logs <payment-pod> -n production | head -20
   kubectl get gateway,httproute -n production
   ```

2. **Respuesta de pago exitosa (captura JSON):**
   ```json
   {
     "transactionId": "aBc12D3E",
     "status": "APPROVED",
     "productId": "PROD-002",
     "quantity": 2,
     "amount": 39.98,
     "message": "Payment processed for Product: ...",
     "timestamp": "2026-11-02T15:30:45Z"
   }
   ```

3. **Preguntas de reflexión:**
   - ¿Cómo se comunican internamente catalog, inventory y payment sin Service Mesh?
   - ¿Por qué payment-service tiene 2 replicas? ¿Qué pasa si uno falla?
   - ¿Qué hace `@Timeout(3000)` en PaymentService?
   - ¿Por qué usamos `--cacert` en lugar de `-k` para validar TLS?
   - ¿Cómo sabría payment-service dónde está inventory-service si no fuera por DNS?

4. **Diagram (en texto o imagen):**
   ```
   [Cliente HTTPS] 
        ↓ (port-forward:8443)
   [Envoy Gateway - Payment.local]
        ↓ (HTTP interno)
   [Payment Service Pod(s)]
        ├→ (HTTP) [Catalog Service]
        └→ (HTTP) [Inventory Service]
   ```

---

## Continuidad con Laboratorio 3.2

En el próximo laboratorio, agregaremos `NetworkPolicy` para aislar la comunicación. Antes de ese paso, identifica:

1. Namespace y etiquetas exactas de los **Pods de datos de Envoy** (no el control plane):
   ```bash
   kubectl get pods -n envoy-gateway-system -o wide --show-labels
   ```

2. Estas etiquetas serán necesarias para permitir ingreso a payment-service desde Envoy.

---

## Fuentes primarias y referencias

- Quarkus 3.40+: REST Client, MicroProfile Fault Tolerance
  - <https://quarkus.io/guides/rest-client>
  - <https://quarkus.io/guides/microprofile-fault-tolerance>
  
- Kubernetes Networking: CoreDNS Service Discovery
  - <https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/>
  
- Gateway API v1 (Kubernetes SIG-Network)
  - <https://gateway-api.sigs.k8s.io/guides/getting-started/intro/>
  
- Envoy Gateway v1.9+
  - <https://gateway.envoyproxy.io/docs/>
  
- JAX-RS (Jakarta EE 10)
  - <https://jakarta.ee/specifications/restful-web-services/>

---

**Laboratorio completado cuando:** Los 3 servicios están corriendo, payment-service se comunica internamente con catalog e inventory, y es accesible externamente vía HTTPS mediante Gateway API.
