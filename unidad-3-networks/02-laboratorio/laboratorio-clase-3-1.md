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

- **Kubernetes 1.32.0 o superior** (Kong Gateway v3.9.1 es totalmente compatible; ver [Actualizar Minikube](../01-clase/anexo-actualizar-minikube-k8s.md))
- Minikube v1.32+ o Kind con Kubernetes 1.32.0+ instalado y ejecutándose
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

## Conexión con la clase 3.1

**Conceptos teóricos aplicados en este laboratorio:**

En Clase 3.1 aprendiste cómo Kubernetes expone servicios mediante **Services** y recursos de entrada como **Gateway API**. Este laboratorio pone en práctica esos conceptos:

| Concepto de clase | Implementación en el laboratorio |
|---|---|
| **ClusterIP (Service)** | `catalog-service` e `inventory-service` usan ClusterIP (acceso interno). `payment-service` también usa ClusterIP internamente. |
| **Comunicación inter-pod** | `payment-service` realiza llamadas HTTP reales a `catalog-service` e `inventory-service` usando nombres DNS internos, todos en puerto 8080 (`catalog-service:8080`, `inventory-service:8080`). |
| **Gateway API** | Exponemos `payment-service` públicamente mediante **Kong Gateway** con recurso `Gateway` y `HTTPRoute`, con terminación TLS. |
| **Caso de uso E-commerce** | Implementas el escenario exacto descrito en clase: 3 microservicios donde payment orquesta, catalog y inventory son internos, y payment es accesible externamente. |

**Arquitectura que construirás:**

```
Internet (HTTPS) 
    ↓ [Kong Gateway + Gateway API]
    ↓ (TLS termination)
payment-service (ClusterIP) 
    ↓ (HTTP interno)
    ├→ catalog-service (ClusterIP) 
    └→ inventory-service (ClusterIP)
```

Los Services internos usan ClusterIP (descrito en clase como el balanceador de capa 4 para consumo interno). El Gateway implementa la entrada HTTP/HTTPS (conceptualmente el "Controlador de entrada" de Clase 3.1).

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

Get-ChildItem catalog-service/, inventory-service/

Select-String "<version>" catalog-service/pom.xml | Select-Object -First 1
Select-String "<version>" inventory-service/pom.xml | Select-Object -First 1
```

**Qué observar:** Ambas carpetas existen con archivos pom.xml legibles. Las versiones deben ser `1.0.0` (catalog) y `1.0.0-SNAPSHOT` (inventory).

> **Importante - Continuidad con U2:** En las unidades previas **no se modificó la versión del `pom.xml`**. En la Unidad 2 (Lab 2.2, Paso 8) el inventory-service pasó a `1.1.0` solo en el código Java (`"v1.1.0"`) y en el tag de la imagen Docker; el `pom.xml` se quedó en `1.0.0-SNAPSHOT`. Por eso aquí **no verás `1.1.0` en el pom.xml**: es lo esperado, no un error. Esta es la primera vez que actualizamos la versión del `pom.xml`.
>
> **Nota sobre manifiestos heredados:** Los directorios `catalog-service/k8s/` e `inventory-service/k8s/` ya existen del Laboratorio 2.2 de Unidad 2. En Paso 5 actualizaremos el manifiesto de inventory-service a v1.2.0 **y normalizaremos su puerto a 8080**. En Paso 16 crearemos manifiestos nuevos para payment-service (también en puerto 8080). En Paso 17 (Desplegar), desplegaremos los 3 servicios con puertos consistentes: todos en 8080. La reutilización y mejora iterativa de componentes es la esencia del desarrollo: cada unidad construye y perfecciona lo anterior.

---

### Paso 2: Abrir el proyecto inventory-service y actualizar pom.xml a la versión 1.2.0

**Qué hace:** Cambia la versión del pom.xml y prepara para agregar nueva funcionalidad.

**Por qué:** Semantic versioning: MINOR bump para endpoint nuevo backward-compatible.

**Modificar el archivo:**

Abre el proyecto completo en tu IDE (`unidad-3-networks/02-laboratorio/proyecto-base-unidad-03`). Los próximos pasos requerirán múltiples modificaciones en varios archivos, así que mantén el proyecto abierto.

Desde el IDE, abre `inventory-service/pom.xml`. Localiza la línea `<version>1.0.0-SNAPSHOT</version>` (normalmente es la primera etiqueta `version` después de `<modelVersion>`). Reemplázala por `<version>1.2.0</version>` y guarda el archivo.

**Qué observar:** El pom.xml ahora muestra `<version>1.2.0</version>`.

**Nota:** No compilamos aún; primero agregamos el código.

---

### Paso 3: Agregar endpoint POST /v1/inventory/reserve a InventoryResource

**Qué hace:** Extiende InventoryResource con un nuevo endpoint para reservar inventario.

**Por qué:** payment-service necesitará reservar stock antes de procesar pagos.

**Modificar el archivo:**

Abre `inventory-service/src/main/java/com/ecom/inventory/InventoryResource.java`. Ubica el cierre de la clase (antes de la última `}`). Agrega el siguiente código:

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

Guarda el archivo.

**Qué observar:** El archivo ahora tiene dos métodos: `@GET /inventory` (heredado) y `@POST /reserve` (nuevo).

**Nota pedagógica:** Observe que el método retorna un `ReservationResponse` con timestamp. Esto es importante para auditoría en sistemas de pagos reales.

---

### Paso 4: Compilar y publicar inventory-service v1.2.0 a Docker Hub

**Qué hace:** Compila el JAR, crea imagen Docker y la publica con etiqueta v1.2.0.

**Por qué:** payment-service necesitará llamar a esta versión con el nuevo endpoint.

**Compilar y publicar:**

Desde tu IDE puedes ejecutar Maven directamente, o abrir una terminal. Los comandos son los mismos en ambos casos.

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
```

![win](images/windows.png) **Windows (PowerShell):**

```powershell
cd inventory-service

mvn clean package -DskipTests

Get-ChildItem -Path target/quarkus-app/

docker build -t <tu_usuario>/inventory-service:1.2.0 .

docker push <tu_usuario>/inventory-service:1.2.0

docker inspect <tu_usuario>/inventory-service:1.2.0
```

**Qué observar:** `docker push` debe completarse sin errores. En Docker Hub, la imagen aparece con el tag `1.2.0`.

**Nota:** Reemplaza `<tu_usuario>` con tu usuario real de Docker Hub (ej: `jdoe`).

---

### Paso 5: Actualizar manifiesto de inventory-service a v1.2.0

**Qué hace:** Modificar el archivo `deployment-service.yaml` heredado de U2 para usar la imagen v1.2.0 que acabamos de compilar y normalizar el puerto a 8080.

**Por qué:** El manifest de U2 todavía referencia `inventory-service:1.0.0`. Como compilamos v1.2.0 con el nuevo endpoint `/reserve`, el manifest debe actualizarse para usar esa versión. Además, es el momento perfecto para normalizar el puerto a 8080, igual que catalog-service y payment-service, para consistencia en U3.

**Modificar el archivo:**

En el IDE, abre `inventory-service/k8s/deployment-service.yaml`. Realiza dos cambios:

1. Busca la línea que dice:

```yaml
image: <tu-usuario-dockerhub>/inventory-service:1.0.0
```

Reemplázala por:

```yaml
image: <tu-usuario-dockerhub>/inventory-service:1.2.0
```

2. Busca la sección `Service` (al final del archivo), específicamente esta parte:

```yaml
---
apiVersion: v1
kind: Service
metadata:
  name: inventory-service
  labels:
    app: inventory-service
spec:
  type: ClusterIP
  selector:
    app: inventory-service
  ports:
  - port: 80
    targetPort: 8080
    protocol: TCP
    name: http
```

Cambia `port: 80` a `port: 8080`:

```yaml
  ports:
  - port: 8080
    targetPort: 8080
    protocol: TCP
    name: http
```

Guarda el archivo.

**Qué observar:** El archivo ahora referencia la imagen v1.2.0 y expone puerto 8080. Cuando desplegemos en Paso 17, Kubernetes tirará esta versión (con el endpoint nuevo `/reserve`) en el puerto correcto.

**Nota pedagógica:** Este paso hace dos cosas importantes:
1. **Versionado de imágenes**: Cada cambio de código → nueva versión → manifiesto actualizado. Este es el ciclo vida de un servicio en producción.
2. **Normalización**: Normalizamos los puertos de todos los servicios a 8080 (catalog, inventory, payment), lo que simplifica la configuración y la comunicación inter-pod. Esta es una decisión arquitectónica común en nuevas versiones de sistemas.

---

### Paso 6: Crear estructura Maven para payment-service

**Qué hace:** Genera nuevo proyecto Quarkus con pom.xml y estructura estándar.

**Por qué:** payment-service es completamente nuevo; usamos Maven archetype para scaffolding consistente.

![linux](images/linux.png) **Linux/macOS:**

```bash
cd proyecto-base-unidad-03

# Generar proyecto con Maven
mvn io.quarkus.platform:quarkus-maven-plugin:3.40.1.1:create \
  -DprojectGroupId=com.ecom \
  -DprojectArtifactId=payment-service \
  -DclassName="com.ecom.payment.PaymentResource" \
  -Dpath="/v1/payments" \
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
  -DclassName="com.ecom.payment.PaymentResource" `
  -Dpath="/v1/payments" `
  -Dextensions="rest-jackson,smallrye-health,smallrye-fault-tolerance,rest-client-jackson"

cd payment-service

Get-ChildItem

Select-String "<version>" pom.xml | Select-Object -First 2
```

**Qué observar:** Se crea directorio `payment-service/` con:
- `pom.xml` (con version `1.0.0-SNAPSHOT`)
- `src/main/java/com/ecom/payment/`
- `Dockerfile`
- `mvnw`, `mvnw.cmd`

---

### Paso 7: Abrir payment-service en el IDE y actualizar pom.xml a versión 1.0.0

**Qué hace:** Cambia version de SNAPSHOT a 1.0.0 de producción.

**Por qué:** No publicamos SNAPSHOT a Docker Hub; usamos versiones semánticas estables.

**Modificar el archivo:**

En el IDE, abre el directorio `payment-service` que acabas de crear. Localiza y abre `pom.xml`. Busca la línea `<version>1.0.0-SNAPSHOT</version>` (normalmente es la primera etiqueta `version` después de `<modelVersion>`). Reemplázala por `<version>1.0.0</version>` y guarda el archivo.

**Qué observar:** pom.xml ahora muestra `<version>1.0.0</version>`.

---

### Paso 8: Crear CatalogClient (cliente HTTP a catalog-service)

**Qué hace:** Define el cliente HTTP que llama a `GET /v1/products/{id}` en catalog-service.

**Por qué:** payment-service necesita validar que el producto existe antes de procesar un pago.

**Crear el archivo:**

En el IDE, dentro del proyecto `payment-service`, crea el archivo `src/main/java/com/ecom/payment/CatalogClient.java`. Agrega el siguiente contenido:

```java
package com.ecom.payment;

import jakarta.ws.rs.GET;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.PathParam;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;
import org.eclipse.microprofile.rest.client.inject.RegisterRestClient;

@RegisterRestClient(configKey = "catalog-api")
@Path("/v1/products")
@Produces(MediaType.APPLICATION_JSON)
public interface CatalogClient {

    @GET
    @Path("/{id}")
    ProductResponse getProduct(@PathParam("id") String productId);

    public record ProductResponse(
        String id,
        String name,
        double price,
        String category
    ) {}
}
```

Guarda el archivo.

**Qué observar:** Esta es una interfaz JAX-RS que actúa como cliente HTTP dentro de payment-service. La anotación `@RegisterRestClient(configKey = "catalog-api")` vincula esta interfaz con la configuración en `application.properties` (que haremos en Paso 13). MicroProfile inyecta automáticamente la implementación en runtime.

**Nota pedagógica:** Esta clase se ejecuta **dentro de payment-service**, pero se conecta a `catalog-service:8080` (nombre DNS interno de Kubernetes del servicio catalog). Este es el patrón de **comunicación inter-pod**: un Pod de payment-service busca otro Pod de catalog-service usando el nombre del Service interno.

---

### Paso 9: Crear InventoryClient (cliente HTTP a inventory-service)

**Qué hace:** Define el cliente HTTP que llama a `POST /v1/inventory/reserve` en inventory-service.

**Por qué:** payment-service debe reservar stock disponible antes de procesar un pago.

**Crear el archivo:**

En el IDE, dentro del proyecto `payment-service`, crea el archivo `src/main/java/com/ecom/payment/InventoryClient.java`. Agrega el siguiente contenido:

```java
package com.ecom.payment;

import jakarta.ws.rs.Consumes;
import jakarta.ws.rs.POST;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;
import org.eclipse.microprofile.rest.client.inject.RegisterRestClient;
import java.time.Instant;

@RegisterRestClient(configKey = "inventory-api")
@Path("/v1/inventory")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
public interface InventoryClient {

    @POST
    @Path("/reserve")
    ReservationResponse reserveInventory(ReservationRequest request);

    public record ReservationRequest(String productId, int quantity) {}
    
    public record ReservationResponse(
        String productId,
        int reservedQuantity,
        String status,
        Instant timestamp
    ) {}
}
```

Guarda el archivo.

**Qué observar:** Esta es una interfaz JAX-RS que actúa como cliente HTTP dentro de payment-service. La anotación `@RegisterRestClient(configKey = "inventory-api")` vincula esta interfaz con la configuración en `application.properties` (que haremos en Paso 13). MicroProfile inyecta automáticamente la implementación en runtime.

**Nota pedagógica:** Esta clase se ejecuta **dentro de payment-service**, pero se conecta a `inventory-service:8080` (nombre DNS interno de Kubernetes del servicio inventory). Ambos clientes (CatalogClient e InventoryClient) siguen el patrón de **comunicación inter-pod**: un Pod de payment-service busca otros Pods de catalog e inventory usando los nombres de los Services internos en puerto 8080.

---

### Paso 10: Crear PaymentService (orquestación con MicroProfile FaultTolerance)

**Qué hace:** Implementa la lógica de orquestación: valida producto, reserva inventario, simula procesamiento de pago.

**Por qué:** Centraliza la lógica de negocio e integra los dos clientes HTTP con resiliencia (`@Timeout`, `@Retry`).

**Crear el archivo:**

En el IDE, dentro del proyecto `payment-service`, crea el archivo `src/main/java/com/ecom/payment/PaymentService.java`. Agrega el siguiente contenido:

```java
package com.ecom.payment;

import jakarta.enterprise.context.ApplicationScoped;
import org.eclipse.microprofile.faulttolerance.Retry;
import org.eclipse.microprofile.faulttolerance.Timeout;
import org.eclipse.microprofile.rest.client.inject.RestClient;
import java.time.Instant;
import java.util.UUID;

@ApplicationScoped
public class PaymentService {

    @RestClient
    CatalogClient catalogClient;

    @RestClient
    InventoryClient inventoryClient;

    @Timeout(3000)
    @Retry(maxRetries = 2, delay = 500)
    public PaymentResponse processPayment(PaymentRequest request) {
        String transactionId = UUID.randomUUID().toString().substring(0, 12).toUpperCase();
        
        try {
            // Validar producto en catalog
            CatalogClient.ProductResponse product = catalogClient.getProduct(request.productId());
            if (product == null) {
                return new PaymentResponse(transactionId, "FAILED", request.productId(), 
                    request.quantity(), request.amount(), "Product not found", Instant.now());
            }
            
            // Reservar en inventory
            InventoryClient.ReservationResponse reservation = 
                inventoryClient.reserveInventory(new InventoryClient.ReservationRequest(
                    request.productId(), request.quantity()));
            
            if (!"RESERVED".equals(reservation.status())) {
                return new PaymentResponse(transactionId, "FAILED", request.productId(), 
                    request.quantity(), request.amount(), "Inventory not available", Instant.now());
            }
            
            // Simular procesamiento de pago (90% éxito)
            boolean paymentApproved = Math.random() < 0.9;
            String status = paymentApproved ? "APPROVED" : "FAILED";
            String message = paymentApproved ? "Payment processed successfully" : "Payment declined by processor";
            
            return new PaymentResponse(transactionId, status, request.productId(), 
                request.quantity(), request.amount(), message, Instant.now());
                
        } catch (Exception e) {
            return new PaymentResponse(transactionId, "FAILED", request.productId(), 
                request.quantity(), request.amount(), "Service error: " + e.getMessage(), Instant.now());
        }
    }

    // Records for request/response
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

Guarda el archivo.

**Qué observar:** La clase es anotada con `@ApplicationScoped` (singleton). Inyecta ambos clientes con `@RestClient`. Los métodos tienen `@Timeout` (límite de 3 segundos total) y `@Retry` (reintentos automáticos). El flujo es claro: validar → reservar → pagar.

**Nota pedagógica:** El 90% de éxito simula un "mundo real" donde los pagos a veces fallan. Los reintentos automáticos mejoran resilencia ante fallos transitorios de red.

---

### Paso 11: Crear StartupHealthCheck para payment-service

**Qué hace:** Define un health check que valida si la aplicación arrancó correctamente, usado por Kubernetes en el startup probe.

**Por qué:** El `startupProbe` en el manifiesto pregunta periódicamente si el servicio está listo. Sin este check, Kubernetes no puede confirmar que la JVM arrancó.

**Crear el archivo:**

En el IDE, en el directorio `src/main/java/com/ecom/payment/`, crea un nuevo archivo llamado `StartupHealthCheck.java`:

```java
package com.ecom.payment;

import org.eclipse.microprofile.health.HealthCheck;
import org.eclipse.microprofile.health.HealthCheckResponse;
import org.eclipse.microprofile.health.Startup;
import jakarta.enterprise.context.ApplicationScoped;

/**
 * Startup Health Check para el servicio de pagos.
 * 
 * Este health check determina si la aplicación arrancó correctamente.
 * Kubernetes usa este endpoint (/health/startup) para decidir cuándo
 * el Pod está listo para recibir tráfico (readiness probe).
 * 
 * A diferencia de readinessProbe y livenessProbe, startupProbe se ejecuta
 * SOLO al inicio hasta que devuelve UP. Luego Kubernetes lo ignora.
 * 
 * En producción, este check validaría:
 * - Conectividad a bases de datos críticas
 * - Carga de configuraciones externas
 * - Validación de dependencias inyectadas
 * 
 * Para esta unidad, simplemente devolvemos UP (la aplicación arrancó).
 */
@Startup
@ApplicationScoped
public class StartupHealthCheck implements HealthCheck {

    /**
     * Verifica que el servicio de pagos arrancó correctamente.
     * 
     * @return HealthCheckResponse con estado UP
     */
    @Override
    public HealthCheckResponse call() {
        // En producción, aquí validaríamos conectividad real a servicios críticos
        // Por ahora, si este método se invoca, significa que Quarkus arrancó exitosamente
        return HealthCheckResponse.up("payment-startup-check");
    }
}
```

Guarda el archivo.

**Qué observar:** La anotación `@Startup` vincula este check con el endpoint `/health/startup`. La lógica es simple: si podemos devolver una respuesta, Quarkus arrancó correctamente. En aplicaciones más complejas, este método haría validaciones exhaustivas antes de permitir tráfico.

**Nota pedagógica:** El patrón de tres health checks (startup, readiness, liveness) es el estándar en Kubernetes:
- **Startup**: ¿Terminó la inicialización? (solo se ejecuta al inicio)
- **Readiness**: ¿Está listo para recibir tráfico? (continuo, después de startup OK)
- **Liveness**: ¿Sigue vivo o se quedó colgado? (continuo, detecta deadlocks)

---

### Paso 12: Reemplazar PaymentResource (REST endpoint)

**Qué hace:** Redefine el endpoint HTTP `/v1/payments` que expone el servicio de pagos.

**Por qué:** Maven generó una plantilla básica; necesitamos reemplazarla con la implementación real que delega a PaymentService.

**Modificar el archivo:**

En el IDE, abre el archivo `src/main/java/com/ecom/payment/PaymentResource.java` (generado por Maven en Paso 6). Reemplaza todo su contenido con lo siguiente:

```java
package com.ecom.payment;

import jakarta.inject.Inject;
import jakarta.ws.rs.*;
import jakarta.ws.rs.core.MediaType;

@Path("/v1/payments")
@Consumes(MediaType.APPLICATION_JSON)
@Produces(MediaType.APPLICATION_JSON)
public class PaymentResource {

    @Inject
    PaymentService paymentService;

    @POST
    public PaymentService.PaymentResponse processPayment(PaymentService.PaymentRequest request) {
        return paymentService.processPayment(request);
    }
}
```

Guarda el archivo.

**Qué observar:** Este controlador REST es deliberadamente simple: solo inyecta `PaymentService` y delega la solicitud. No define sus propios records (usa `PaymentService.PaymentRequest` y `PaymentService.PaymentResponse`). No maneja excepciones porque `PaymentService` ya lo hace, retornando siempre una respuesta válida (con estado FAILED si hay problemas).

**Nota pedagógica:** Observa la arquitectura en capas implementada:
- **Clientes (Pasos 7-8)**: Hablan con otros servicios (catalog, inventory)
- **Servicio (Paso 9)**: Orquesta la lógica de negocio, coordina clientes, maneja excepciones
- **Resource (Paso 10)**: Solo expone HTTP, delega todo al servicio

Esta separación hace el código testeable, mantenible y resiliente. El Resource es "dumb" (simple), el Service es "smart" (inteligente).

---

### Paso 13: Configurar application.properties

**Qué hace:** Define propiedades de configuración de Quarkus para payment-service, incluyendo URLs de los servicios remotos.

**Por qué:** Centraliza la configuración (puertos, URLs de clientes HTTP, health checks) en un lugar.

**Modificar el archivo:**

En el IDE, abre o crea el archivo `src/main/resources/application.properties`. Agrega el siguiente contenido:

```properties
# Server configuration
quarkus.http.port=8080
quarkus.http.host=0.0.0.0
quarkus.application.name=payment-service
quarkus.application.version=1.0.0
quarkus.smallrye-health.root-path=/health

# REST Client configuration for catalog-service
quarkus.rest-client."catalog-api".url=http://catalog-service:8080

# REST Client configuration for inventory-service
quarkus.rest-client."inventory-api".url=http://inventory-service:8080
```

Guarda el archivo.

**Qué observar:** Las URLs de los clientes HTTP (`catalog-api` e `inventory-api`) usan nombres DNS internos de Kubernetes, ambos en puerto 8080:
- `catalog-service:8080`
- `inventory-service:8080`

Kubernetes CoreDNS resuelve automáticamente estos nombres a las IPs de los Services correspondientes.

**Nota pedagógica:** Las propiedades con `quarkus.rest-client` se mapean a las interfaces `@RegisterRestClient` que definimos en los Pasos 7-8 mediante el parámetro `configKey`.

---

### Paso 14: Crear Dockerfile para payment-service

**Qué hace:** Define cómo empaquetar payment-service en una imagen Docker lista para Kubernetes.

**Por qué:** Docker empaqueta solo el JAR compilado (sin herramientas de build), reduciendo tamaño y riesgo de seguridad. Usamos la misma imagen base que en Unidad 2.

**Crear el archivo:**

En el IDE, en la raíz de `payment-service/`, crea el archivo `Dockerfile` con el siguiente contenido:

```dockerfile
FROM registry.access.redhat.com/ubi9/openjdk-25-runtime:1.24

ENV LANGUAGE='en_US:en'

# We make four distinct layers so if there are application changes the library layers can be re-used
COPY --chown=185 target/quarkus-app/lib/ /deployments/lib/
COPY --chown=185 target/quarkus-app/*.jar /deployments/
COPY --chown=185 target/quarkus-app/app/ /deployments/app/
COPY --chown=185 target/quarkus-app/quarkus/ /deployments/quarkus/

EXPOSE 8080
USER 185
ENV JAVA_OPTS_APPEND="-Dquarkus.http.host=0.0.0.0 -Djava.util.logging.manager=org.jboss.logmanager.LogManager"
ENV JAVA_APP_JAR="/deployments/quarkus-run.jar"

ENTRYPOINT [ "/opt/jboss/container/java/run/run-java.sh" ]
```

Guarda el archivo.

**Qué observar:** Este Dockerfile es idéntico al de Unidad 2 (inventory-service). Usa:
- **Red Hat UBI9** como imagen base (runtime-only, sin herramientas de build)
- **Multi-layer copy** para optimizar cachés de Docker
- **USER 185** por razones de seguridad (non-root)
- **EXPOSE 8080** porque Quarkus corre en ese puerto

**Nota pedagógica:** Es el mismo Dockerfile usado en toda la plataforma (catalog, inventory, payment). La consistencia en tooling reduce sorpresas.

---

### Paso 15: Compilar y publicar payment-service v1.0.0 a Docker Hub

**Qué hace:** Compila el JAR, crea imagen Docker con el Dockerfile del Paso 14, publica como v1.0.0.

**Por qué:** Es la versión lista para desplegar en Kubernetes.

![linux](images/linux.png) **Linux/macOS:**

```bash
# Desde directorio payment-service/
mvn clean package -DskipTests

# Verifica JAR
ls -la target/quarkus-app/

# Construir imagen (usa el Dockerfile creado en Paso 14)
docker build -t <tu_usuario>/payment-service:1.0.0 .

# Publicar
docker push <tu_usuario>/payment-service:1.0.0

# Verifica en Docker Hub
curl -s "https://hub.docker.com/v2/repositories/<tu_usuario>/payment-service/tags" | grep "1.0.0"
```

![win](images/windows.png) **Windows (PowerShell):**

```powershell
mvn clean package -DskipTests

Get-ChildItem -Path target/quarkus-app/

docker build -t <tu_usuario>/payment-service:1.0.0 .

docker push <tu_usuario>/payment-service:1.0.0

# Verifica (requiere curl)
curl -s "https://hub.docker.com/v2/repositories/<tu_usuario>/payment-service/tags"
```

**Qué observar:** `docker push` completa exitosamente. Imagen aparece en Docker Hub.

**Nota:** Reemplaza `<tu_usuario>` con tu usuario real de Docker Hub.

---

### Paso 16: Crear manifestos Kubernetes para payment-service

**Qué hace:** Definir cómo Kubernetes ejecutará payment-service con configuración de resiliencia y networking.

**Por qué:** Los manifiestos YAML especifican a Kubernetes:
- Cuántas réplicas ejecutar (resiliencia a fallos)
- Cómo actualizar sin downtime (rolling updates con cero-downtime)
- Si un Pod está listo para recibir tráfico (readiness probe)
- Si un Pod sigue vivo o se quedó colgado (liveness probe)
- Cómo exponer el servicio internamente (ClusterIP para comunicación inter-pod)

**Nota de transición:** Hasta ahora hemos desarrollado código Java en el IDE (Pasos 2-12), creado el Dockerfile (Paso 14), y compilado + publicado la imagen Docker (Paso 15). Ahora creamos los archivos de configuración Kubernetes que describen cómo ejecutar la aplicación en el clúster. Estos también se crean en el IDE como archivos de proyecto.

**Crear el archivo:**

En el IDE, desde la raíz del proyecto, crea la carpeta `payment-service/k8s/` (si no existe). Dentro de `payment-service/k8s/`, crea el archivo `deployment-service.yaml` con el siguiente contenido:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: payment-service
  labels:
    app: payment-service
spec:
  replicas: 2
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1           # Permite 1 Pod extra durante actualización
      maxUnavailable: 0     # NUNCA permite 0 Pods: zero-downtime
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
          imagePullPolicy: Always            # Siempre tira imagen fresca de Docker Hub
          ports:
            - containerPort: 8080
              name: http
          resources:
            requests:
              cpu: 100m
              memory: 256Mi
            limits:
              cpu: 500m
              memory: 512Mi
        
          # 1. StartupProbe: ¿Arrancó la JVM correctamente?
          # Endpoint: curl http://localhost:8080/health
          startupProbe:
            httpGet:
              path: /health
              port: 8080
            initialDelaySeconds: 0
            periodSeconds: 2
            timeoutSeconds: 1
            failureThreshold: 30          # Máx 30 reintentos (60 segundos)
        
          # 2. ReadinessProbe: ¿Listo para recibir tráfico?
          # Endpoint: curl http://localhost:8080/health/ready
          readinessProbe:
            httpGet:
              path: /health/ready
              port: 8080
            initialDelaySeconds: 10
            periodSeconds: 5
            timeoutSeconds: 2
            failureThreshold: 2
        
          # 3. LivenessProbe: ¿Sigue vivo o se quedó colgado?
          # Endpoint: curl http://localhost:8080/health/live
          livenessProbe:
            httpGet:
              path: /health/live
              port: 8080
            initialDelaySeconds: 30
            periodSeconds: 10
            timeoutSeconds: 3
            failureThreshold: 3

---
apiVersion: v1
kind: Service
metadata:
  name: payment-service
  labels:
    app: payment-service
spec:
  type: ClusterIP
  selector:
    app: payment-service
  ports:
    - port: 8080
      targetPort: 8080
      protocol: TCP
      name: http
```

Guarda el archivo.

**Qué observar:**

**Archivo creado:**

```
payment-service/k8s/
└── deployment-service.yaml    # Deployment + Service juntos
```

**Estructura del archivo:**

El archivo combina dos recursos Kubernetes (separated by `---`):
1. **Deployment** (líneas 1-62): Cómo ejecutar payment-service
2. **Service** (líneas 64-76): Cómo exponer payment-service internamente

Este es el mismo patrón que usaste en Unidad 2 Lab 2.2 para `inventory-service`.

**Elementos clave en el Deployment:**

| Elemento | Propósito | Observación |
|----------|-----------|-------------|
| `replicas: 2` | 2 Pods corriendo simultáneamente | Resiliencia: si uno falla, el otro atiende |
| `maxSurge: 1, maxUnavailable: 0` | Rolling update sin downtime | Durante actualización: máx 3 Pods, mín 2 Pods siempre activos |
| `imagePullPolicy: Always` | Siempre traer imagen fresca de Docker Hub | Asegurar que no usas versión cacheada del nodo |
| `startupProbe` (30 reintentos × 2s) | 60 segundos para iniciar JVM | Java startup es lento; este tiempo es normal |
| `readinessProbe` (10 segundos) | Esperar antes de enviar tráfico | Asegurar que la app está lista (DB connections, etc.) |
| `livenessProbe` (30 segundos) | Detectar "hangs" y reintentar | Si no responde, Kubernetes reinicia el Pod |
| `resources.requests` | Garantizar recursos mínimos | Kubernetes coloca el Pod si hay >= 100m CPU + 256Mi RAM |
| `resources.limits` | Evitar que consume todo | Si sobrepasa 500m CPU o 512Mi RAM, se mata |

**Elementos clave en el Service:**

| Elemento | Propósito | Observación |
|----------|-----------|-------------|
| `type: ClusterIP` | Acceso interno únicamente (default) | No es accesible desde fuera del clúster (Gateway lo expondrá en Paso 19) |
| `port: 8080` | Puerto de escucha del Service | Los Pods internos usan este puerto para comunicarse |
| `targetPort: 8080` | Puerto del contenedor | Service redirecciona puerto 8080 → containerPort 8080 |

**Nota pedagógica - Continuidad con Unidad 2:**

Los Health Checks (`startupProbe`, `readinessProbe`, `livenessProbe`) son exactamente los mismos mecanismos que usaste en Unidad 2 Lab 2.2 para `inventory-service`. Aquí vemos cómo son reutilizables en cualquier microservicio. Los valores específicos pueden variar (Unidad 2 usaba `/health/started`, aquí usamos `/health/startup`), pero el concepto es idéntico.

**Nota pedagógica - RollingUpdate con cero-downtime:**

La configuración `maxSurge: 1` + `maxUnavailable: 0` implementa lo que Clase 3.1 enseñó: actualizaciones sin interrupción de tráfico. Durante la actualización de v1.0.0 a v1.0.1 (en futuro):
1. Kubernetes crea 1 Pod nuevo (maxSurge: 1) → total 3 Pods (v1.0.0 + v1.0.0 + v1.0.1 nuevo)
2. Envía tráfico al nuevo Pod (readinessProbe confirma listo)
3. Mata 1 Pod viejo → total 2 Pods (v1.0.0 + v1.0.1)
4. Repite hasta que solo quedan 2 Pods v1.0.1
5. Resultado: Cero downtime, tráfico siempre atendido

---

### Paso 17: Desplegar los 3 servicios en Kubernetes

**Qué hace:** Aplica manifiestos de catalog, inventory, y payment al clúster.

**Por qué:** Es el momento de ver los servicios corriendo juntos.

**Validación previa:**

![linux](images/linux.png) **Linux/macOS:**

```bash
# Verifica que tienes Minikube/Kind ejecutándose
kubectl cluster-info

# Verifica que los 3 servicios tienen manifiestos
find proyecto-base-unidad-03 -name "deployment-service.yaml" -o -name "01-deployment.yaml" -o -name "02-service.yaml" | sort
```

![win](images/windows.png) **Windows (PowerShell):**

```powershell
# Verifica que tienes Minikube/Kind ejecutándose
kubectl cluster-info

# Verifica que los 3 servicios tienen manifiestos
Get-ChildItem -Path proyecto-base-unidad-03 -Recurse -Include "deployment-service.yaml", "01-deployment.yaml", "02-service.yaml" | Sort-Object FullName | ForEach-Object { $_.FullName -replace '\\', '/' }
```

**Salida esperada (ambos):**

```bash
proyecto-base-unidad-03/catalog-service/k8s/01-deployment.yaml
proyecto-base-unidad-03/catalog-service/k8s/02-service.yaml
proyecto-base-unidad-03/inventory-service/k8s/deployment-service.yaml
proyecto-base-unidad-03/payment-service/k8s/deployment-service.yaml
```

**Si obtienes esta salida, significa que todos los manifiestos están en su lugar.**

![linux](images/linux.png) **Desplegar (Linux/macOS):**

```bash
cd proyecto-base-unidad-03

# Desplegar catalog-service (heredado de U2)
kubectl apply -f catalog-service/k8s/01-deployment.yaml
kubectl apply -f catalog-service/k8s/02-service.yaml

# Desplegar inventory-service v1.2.0
kubectl apply -f inventory-service/k8s/config-secrets.yaml
kubectl apply -f inventory-service/k8s/deployment-service.yaml

# Desplegar payment-service v1.0.0
kubectl apply -f payment-service/k8s/deployment-service.yaml

# Espera a que los Pods estén Ready
kubectl rollout status deployment/catalog-service --timeout=120s
kubectl rollout status deployment/inventory-service --timeout=120s
kubectl rollout status deployment/payment-service --timeout=120s

# Verifica estado
kubectl get pods -o wide
kubectl get svc
```

![win](images/windows.png) **Desplegar (Windows - PowerShell):**

```powershell
cd proyecto-base-unidad-03

kubectl apply -f catalog-service/k8s/01-deployment.yaml
kubectl apply -f catalog-service/k8s/02-service.yaml

kubectl apply -f inventory-service/k8s/deployment-service.yaml

kubectl apply -f payment-service/k8s/deployment-service.yaml

kubectl rollout status deployment/catalog-service --timeout=120s
kubectl rollout status deployment/inventory-service --timeout=120s
kubectl rollout status deployment/payment-service --timeout=120s

kubectl get pods -o wide
kubectl get svc
```

**Qué observar:** 
- Todos los Pods están en `Running`:
  - catalog-service: 1 Pod (por diseño de Lab 1.3)
  - inventory-service: 2 replicas
  - payment-service: 2 replicas
  - **Total: 5 Pods**
- Los Services tienen ClusterIP asignadas
- `kubectl logs pod/<pod_name>` muestra logs de Quarkus sin errores

**Nota pedagógica:** Los Pods pueden tardar 30-60 segundos en iniciar debido a `startupProbe`. Es normal.

---

### Paso 18: Probar comunicación inter-servicios (sin Gateway aún)

**Qué hace:** Verifica que payment-service puede alcanzar catalog e inventory internamente.

**Por qué:** Validar la arquitectura antes de exponerla externamente.

![linux](images/linux.png) **Linux/macOS:**

```bash
# Acceder a un Pod de payment-service
POD_NAME=$(kubectl get pods -l app=payment-service -o jsonpath='{.items[0].metadata.name}')

# Prueba 1: Ver logs
kubectl logs $POD_NAME -f

# Prueba 2: Hacer un curl interno desde otro Pod
kubectl exec -it $POD_NAME -- curl -X POST http://payment-service:8080/v1/payments \
  -H "Content-Type: application/json" \
  -d '{"productId":"PROD-001","quantity":1,"amount":19.99}' 

# Deberías ver respuesta JSON con transactionId y status (APPROVED o FAILED)
```

![win](images/windows.png) **Windows (PowerShell):**

```powershell
$POD_NAME = kubectl get pods -l app=payment-service -o jsonpath='{.items[0].metadata.name}'

kubectl logs $POD_NAME -f

kubectl exec -it $POD_NAME -- curl -X POST http://payment-service:80/v1/payments `
  -H "Content-Type: application/json" `
  -d '{"productId":"PROD-001","quantity":1,"amount":19.99}'
```

**Qué observar:** La respuesta JSON contiene `transactionId` y `status` (APPROVED o FAILED aleatoriamente).

**Nota pedagógica:** Si falla con timeout, puede ser:
1. Pods aún no listo (espera más)
2. Imagen Docker no se descargó (verifica `kubectl describe pod`)
3. DNS no funciona (intenta con IP: `kubectl get svc` y usa ClusterIP)

---

### Paso 19: Instalar Kong Gateway Controller

**Qué hace:** Instala Kong Gateway Controller v3.9.1 para enrutar tráfico HTTP/HTTPS.

**Por qué:** Kong maneja la entrada externa con soporte nativo para Gateway API y TLS.

**✅ Requisito:** Kong funciona perfectamente con Kubernetes 1.32.0+.

**Verificar tu versión de K8s:**
```bash
kubectl version
# Debe mostrar: Server Version: v1.32.0 (o superior)
```

![linux](images/linux.png) **Linux/macOS:**

```bash
# Agrega repositorio de Kong
helm repo add kong https://charts.konghq.com
helm repo update

# Instala Kong Gateway v3.9.1
helm install kong kong/kong \
  --namespace kong-system \
  --create-namespace \
  --wait

# Verifica instalación
kubectl get pods -n kong-system
kubectl get svc -n kong-system
```

![win](images/windows.png) **Windows (PowerShell):**

```powershell
# Agrega repositorio de Kong
helm repo add kong https://charts.konghq.com
helm repo update

# Instala Kong Gateway v3.9.1
helm install kong kong/kong `
  --namespace kong-system `
  --create-namespace `
  --wait

# Verifica instalación
kubectl get pods -n kong-system
kubectl get svc -n kong-system
kubectl get pods -n envoy-gateway-system
```

**Qué observar:** 
- ✅ Pods `kong-kong-*` en estado `Running`
- ✅ Servicio `kong-kong-proxy` con tipo LoadBalancer/NodePort
- ✅ Kong está listo para recibir tráfico

---

### Paso 20: Crear certificado TLS y configurar Gateway + HTTPRoute

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
  --key=payment.key

# Verifica
kubectl get secret
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
  --key=payment.key
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
spec:
  gatewayClassName: eg
  listeners:
    - name: http
      protocol: HTTP
      port: 80
      hostname: payment.local
      allowedRoutes:
        namespaces:
          from: All
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
          from: All
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: payment-route
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

kubectl get gatewayclass,gateway,httproute
kubectl describe gateway payment-gateway
```

**Qué observar:** 
- `GatewayClass` existe y tiene controller asignado
- `Gateway` muestra condiciones `Accepted: True` y `Programmed: True`
- `HTTPRoute` muestra `Accepted: True`

---

### Paso 21: Probar acceso externo con TLS

**Qué hace:** Accede a payment-service desde fuera del clúster via HTTPS usando Gateway.

**Por qué:** Validar que la exposición funciona end-to-end.

![linux](images/linux.png) **Linux/macOS:**

```bash
# Obtener nombre del Service de Kong proxy (creado automáticamente por Gateway)
KONG_SERVICE=$(kubectl get svc -n kong-system -l app.kubernetes.io/instance=kong \
  -o jsonpath='{.items[0].metadata.name}')

echo "Kong Service: $KONG_SERVICE"

# En una terminal, reenviar puertos
kubectl port-forward -n kong-system "service/$KONG_SERVICE" 8443:443 8080:80 &

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
$KONG_SERVICE = kubectl get svc -n kong-system -l app.kubernetes.io/instance=kong `
  -o jsonpath='{.items[0].metadata.name}'

Write-Host "Kong Service: $KONG_SERVICE"

# En PowerShell, start port-forward en background
Start-Process -NoNewWindow kubectl -ArgumentList "port-forward", "-n", "kong-system", "service/$KONG_SERVICE", "8443:443", "8080:80"

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
   kubectl get pods,svc
   kubectl logs <payment-pod> | head -20
   kubectl get gateway,httproute
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
   [Kong Gateway - Payment.local]
        ↓ (HTTP interno)
   [Payment Service Pod(s)]
        ├→ (HTTP) [Catalog Service]
        └→ (HTTP) [Inventory Service]
   ```

---

## Continuidad con Laboratorio 3.2

En el próximo laboratorio, agregaremos `NetworkPolicy` para aislar la comunicación. Antes de ese paso, identifica:

1. Namespace y etiquetas exactas de los **Pods de datos de Kong** (no el control plane):
   ```bash
   kubectl get pods -n kong-system -o wide --show-labels
   ```

2. Estas etiquetas serán necesarias para permitir ingreso a payment-service desde Kong.

---

## Fuentes primarias y referencias

- Quarkus 3.40+: REST Client, MicroProfile Fault Tolerance
  - <https://quarkus.io/guides/rest-client>
  - <https://quarkus.io/guides/microprofile-fault-tolerance>
  
- Kubernetes Networking: CoreDNS Service Discovery
  - <https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/>
  
- Gateway API v1 (Kubernetes SIG-Network)
  - <https://gateway-api.sigs.k8s.io/guides/getting-started/intro/>
  
- Kong Gateway v3.9+
  - <https://docs.konghq.com/gateway/>
  
- JAX-RS (Jakarta EE 10)
  - <https://jakarta.ee/specifications/restful-web-services/>

---

**Laboratorio completado cuando:** Los 3 servicios están corriendo, payment-service se comunica internamente con catalog e inventory, y es accesible externamente vía HTTPS mediante Gateway API.
