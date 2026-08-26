# **Unidad 1:** Guía oficial de laboratorio integrador: Resiliencia y alta disponibilidad en arquitecturas cloud-native

## 1. Objetivo del laboratorio y escenario real

**El escenario:** Trabajas como _Junior Cloud Engineer_ en una plataforma e-commerce compuesta por `catalog-service`, `inventory-service`, `payment-service` y `orders-service`. Para esta primera unidad partirás de `u1-starter`, un proyecto base mínimo donde `catalog-service` ya existe como primera pieza funcional del sistema.

Durante el último evento de ventas masivas, el servicio de catálogo colapsó por saturación de nodos y dependencia de una base de datos sin lectura replicada. La dirección de tecnología ha ordenado fortalecer esta primera pieza antes de seguir construyendo el resto de la plataforma.

**El objetivo:** Este laboratorio integra los resultados de los laboratorios parciales [1.1](laboratorio-clase-1-1.md), [1.2](laboratorio-clase-1-2.md) y [1.3](laboratorio-clase-1-3.md). No repite la implementación: consolida el `catalog-service` resiliente, valida su despliegue en Kubernetes y reúne las evidencias necesarias para entregar `u2-starter`.

**Regla de continuidad:** completa los laboratorios parciales en orden. Si comienzas directamente aquí, el proyecto base será ejecutable, pero no tendrá los patrones de resiliencia que se evalúan en la integración.

## 2. Prerrequisitos y stack tecnológico

Antes de iniciar, debes contar con las siguientes herramientas instaladas y funcionales en tu entorno de desarrollo Linux/macOS:

- **Java OpenJDK 25** y **Apache Maven 3.8+**.

- **Docker Engine** (v24.0+) o **Podman**.

- **Minikube** (v1.30+) o **Kind** (Kubernetes v1.28+).

- **kubectl** configurado e interconectado con tu clúster local.

- **Apache Bench (`ab`)** o **curl** para generación de tráfico de prueba.

- **Draw.io**, **Lucidchart** o **Excalidraw** para la generación del diagrama de arquitectura.

## 3. Desglose técnico paso a paso (guía hands-on)

### Paso 1: Mapeo de la arquitectura de resiliencia

Antes de tirar líneas de código o manifiestos, diseña el diagrama arquitectónico de la solución objetivo.

Asegúrate de mapear visualmente:

1. El punto de entrada de tráfico (_LoadBalancer Service_).

2. La distribución de réplicas del microservicio en Quarkus entre 2 zonas de disponibilidad simuladas (`zone-a` y `zone-b`).

3. El aislamiento de fallas (_bulkhead_ y _circuit breaker_) ante la dependencia de la base de datos.

4. La réplica de lectura de la base de datos (_Read Replica_).

### Paso 2: Confirmar el resultado del laboratorio parcial 1.2

Confirma que completaste el [Laboratorio de la clase 1.2](laboratorio-clase-1-2.md) y que `CatalogResource` contiene la implementación de resiliencia. En este laboratorio integrador no se vuelve a desarrollar el código.

#### Archivo `pom.xml` (Dependencias clave)

Asegúrate de tener integradas las siguientes extensiones en tu proyecto Maven:

```xml
<dependencies>
    <dependency>
      <groupId>io.quarkus</groupId>
      <artifactId>quarkus-rest-jackson</artifactId>
    </dependency>
    <dependency>
        <groupId>io.quarkus</groupId>
        <artifactId>quarkus-smallrye-health</artifactId>
    </dependency>
    <dependency>
        <groupId>io.quarkus</groupId>
        <artifactId>quarkus-smallrye-fault-tolerance</artifactId>
    </dependency>
</dependencies>
```

#### Archivo `src/main/java/com/ecom/catalog/CatalogResource.java`

Verifica que el endpoint existente conserva el trabajo realizado en el laboratorio parcial 1.2. Si falta algún patrón, vuelve a ese laboratorio antes de continuar.

```java
package com.ecom.catalog;

import org.eclipse.microprofile.faulttolerance.CircuitBreaker;
import org.eclipse.microprofile.faulttolerance.Fallback;
import org.eclipse.microprofile.faulttolerance.Retry;
import org.eclipse.microprofile.faulttolerance.Timeout;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import java.util.Random;
import java.util.logging.Logger;

@Path("/v1/products")
public class CatalogResource {

    private static final Logger LOG = Logger.getLogger(CatalogResource.class.getName());
    private final Random random = new Random();

    @GET
    @Produces(MediaType.APPLICATION_JSON)
    @Timeout(800) // Cancela la solicitud si toma más de 800ms
    @Retry(maxRetries = 2, delay = 150) // Reintenta máximo 2 veces con 150ms de pausa
    @CircuitBreaker(requestVolumeThreshold = 4, failureRatio = 0.5, delay = 5000) // Abre circuito si falla el 50%
    @Fallback(fallbackMethod = "getCatalogFallback") // Invoca respuesta degradada si falla o se abre el circuito
    public Response getProducts() throws InterruptedException {
        int chance = random.nextInt(10);
        
        // Simular latencia degradada en la base de datos (20% de probabilidad)
        if (chance < 2) {
            LOG.warning("Simulando latencia alta en consulta de catálogo...");
            Thread.sleep(1200);
        }

        // Simular falla de conexión a la base de datos (30% de probabilidad)
        if (chance >= 2 && chance < 5) {
            LOG.severe("Falla de conexión a la base de datos primaria.");
            throw new RuntimeException("Database connection timeout");
        }

        return Response.ok("{\"status\":\"SUCCESS\",\"data\":[\"Product A\",\"Product B\",\"Product C\"]}").build();
    }

    public Response getCatalogFallback() {
        LOG.info("Fallback activado: Sirviendo datos desde la memoria caché local.");
        return Response.ok("{\"status\":\"DEGRADED_CACHE\",\"data\":[\"Cached Product A\",\"Cached Product B\"]}").build();
    }
}
```

#### Archivo `src/main/java/com/ecom/catalog/ReadinessHealthCheck.java`

Verifica el _health check_ existente y sus rutas `/health`, `/ready` y `/live`, según `application.properties`.

```java
package com.ecom.catalog;

import org.eclipse.microprofile.health.HealthCheck;
import org.eclipse.microprofile.health.HealthCheckResponse;
import org.eclipse.microprofile.health.Readiness;
import jakarta.enterprise.context.ApplicationScoped;

@Readiness
@ApplicationScoped
public class ReadinessHealthCheck implements HealthCheck {

    @Override
    public HealthCheckResponse call() {
        // En producción aquí validaríamos conectividad real a DB/Redis
        boolean isReady = checkDatabaseCluster();
        
        if (isReady) {
            return HealthCheckResponse.up("catalog-database-check");
        } else {
            return HealthCheckResponse.down("catalog-database-check");
        }
    }

    private boolean checkDatabaseCluster() {
        return true; 
    }
}
```

### Paso 3: Construcción de la imagen en Docker

Compila la aplicación en un paquete ejecutable y genera la imagen de contenedor:

```bash
# Compilar el proyecto en modo ejecutable fast-jar
./mvnw clean package -DskipTests

# Construir la imagen Docker usando el Dockerfile estándar de Quarkus
docker build -f src/main/docker/Dockerfile.jvm -t catalog-service:1.0.0 .
```

_Nota para Minikube:_ Carga la imagen directamente en el demonio del clúster para evitar registrarla en un _registry_ remoto:

```bash
minikube image load catalog-service:1.0.0
```

### Paso 4: Despliegue en Kubernetes con infraestructura multi-AZ simulada

Simularemos un clúster _multi-AZ_ aplicando etiquetas de topología a nuestros nodos de Kubernetes.

#### Preparación de etiquetas en los nodos

```bash
# Etiquetar el nodo 1 como Zona A
kubectl label nodes minikube topology.kubernetes.io/zone=us-east-1a --overwrite

# (Opcional) Si usas Kind o Minikube multi-nodo, etiqueta el segundo nodo como Zona B:
# kubectl label nodes minikube-m02 topology.kubernetes.io/zone=us-east-1b --overwrite
```

#### Archivos `k8s/01-deployment.yaml` y `k8s/02-service.yaml`

Completa los manifiestos existentes del proyecto base para desplegar 3 réplicas con restricciones de distribución topológica (_Topology Spread Constraints_), probes de salud y balanceo de carga. No crees un archivo `k8s-manifests.yaml` separado.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: catalog-service-deployment
  namespace: default
  labels:
    app: catalog-service
spec:
  replicas: 3
  selector:
    matchLabels:
      app: catalog-service
  template:
    metadata:
      labels:
        app: catalog-service
    spec:
      # Garantiza la distribución equitativa de Pods entre Zonas de Disponibilidad (AZ)
      topologySpreadConstraints:
        - maxSkew: 1
          topologyKey: topology.kubernetes.io/zone
          whenUnsatisfiable: ScheduleAnyway
          labelSelector:
            matchLabels:
              app: catalog-service
        # Garantiza no saturar un solo nodo físico
        - maxSkew: 1
          topologyKey: kubernetes.io/hostname
          whenUnsatisfiable: ScheduleAnyway
          labelSelector:
            matchLabels:
              app: catalog-service

      containers:
        - name: catalog-service
          image: catalog-service:1.0.0
          imagePullPolicy: IfNotPresent
          ports:
            - containerPort: 8080
              name: http
          
          resources:
            requests:
              cpu: "100m"
              memory: "128Mi"
            limits:
              cpu: "300m"
              memory: "256Mi"

          # Configuración de Probes para autocuración
          livenessProbe:
            httpGet:
              path: /health/live
              port: 8080
            initialDelaySeconds: 5
            periodSeconds: 10
            failureThreshold: 3
          readinessProbe:
            httpGet:
              path: /health/ready
              port: 8080
            initialDelaySeconds: 5
            periodSeconds: 5
            failureThreshold: 2

---
apiVersion: v1
kind: Service
metadata:
  name: catalog-service-lb
  namespace: default
spec:
  type: LoadBalancer
  selector:
    app: catalog-service
  ports:
    - protocol: TCP
      port: 80
      targetPort: 8080
```

#### Aplicación de los manifiestos

```bash
kubectl apply -f k8s/01-deployment.yaml
kubectl apply -f k8s/02-service.yaml
```

### Paso 5: Simulación de fallos en vivo y validación de resiliencia

1. **Monitoreo de estado inicial:**

    Verifica que las 3 réplicas estén en estado `Running` y hayan pasado la prueba de _Readiness_:

    ```bash
    kubectl get pods -l app=catalog-service -o wide
    ```

2. **Simulación de carga masiva y fallas de aplicación:**

    Abre una terminal y lanza 100 peticiones concurrentes para forzar al _Circuit Breaker_ a actuar ante las fallas simuladas de la base de datos:

    ```bash
    for i in {1..50}; do curl -s http://$(minikube ip):80/v1/products; echo ""; done
    ```

    _Resultado esperado:_ Verás que algunas peticiones devuelven `SUCCESS` y otras devuelven `DEGRADED_CACHE` sin arrojar un error HTTP `500`. El _Circuit Breaker_ abrió el circuito y redirigió las peticiones al método de _Fallback_ instantáneamente.

3. **Inyección de falla de infraestructura (destrucción de un Pod en vivo):** Obtén el nombre de uno de los _Pods_ activos y elimina el contenedor abruptamente para validar la respuesta del clúster:

    ```bash
    # Obtener nombre de un Pod
    TARGET_POD=$(kubectl get pods -l app=catalog-service -o jsonpath='{.items[0].metadata.name}')

    # Eliminar el Pod simulando la caída repentina del proceso/servidor
    kubectl delete pod $TARGET_POD --grace-period=0 --force
    ```

4. **Verificación de autocuración (_Self-healing_):**

    Ejecuta inmediatamente:

    ```bash
    kubectl get pods -l app=catalog-service -w
    ```

    _Resultado esperado:_ El _ReplicaSet_ detecta la desviación del estado deseado y crea automáticamente un nuevo _Pod_ de reemplazo sin interrumpir el servicio procesado por las otras 3 réplicas.

## 4. Guía de troubleshooting (¿qué puede fallar?)

### Problema 1: Los Pods se quedan en estado `CrashLoopBackOff` o `Error`

- **Causa común:** La imagen Docker no está disponible dentro del contexto de ejecución de Kubernetes o el puerto configurado en el _probe_ no coincide con la aplicación.

- **Diagnóstico técnico:**

    ```bash
    # Revisa los eventos específicos del Pod dañado
    kubectl describe pod <nombre-del-pod>
    
    # Revisa los logs directos de la aplicación Java/Quarkus
    kubectl logs <nombre-del-pod> --previous
    ```

- **Solución:** Si estás en Minikube, asegúrate de ejecutar `minikube image load catalog-service:1.0.0` para que el clúster reconozca la imagen local sin intentar descargarla de Docker Hub.

### Problema 2: Los Pods están `Running` pero nunca entran en estado `READY 1/1`

- **Causa común:** La ruta configurada en la `readinessProbe` (`/health/ready`) está mal escrita o la aplicación está tardando más tiempo del permitido por el parámetro `initialDelaySeconds` en responder.

- **Diagnóstico técnico:**

    ```bash
    kubectl get events --sort-by='.metadata.creationTimestamp'
    ```

    Busca un mensaje que indique: `Readiness probe failed: HTTP probe failed with statuscode: 404`.

- **Solución:** Verifica que la extensión `quarkus-smallrye-health` esté presente en el `pom.xml` y incrementa el parámetro `initialDelaySeconds` a `15` en el manifiesto YAML.

### Problema 3: Las peticiones a través del `LoadBalancer Service` fallan con `Connection Refused`

- **Causa común:** El _selector_ del _Service_ no coincide exactamente con las _labels_ definidas en el _template_ del _Deployment_.

- **Diagnóstico técnico:**

    ```bash
    # Verifica si el Service ha asociado IP internas de Pods como Endpoints
    kubectl get endpoints catalog-service-lb
    ```

    Si la columna `ENDPOINTS` aparece como `<none>`, las etiquetas no hacen _match_.

- **Solución:** Corrige la sección `spec.selector` del _Service_ para que sea exactamente igual a `app: catalog-service`.

## 5. Criterios de aceptación / evidencia de entrega

Para considerar este laboratorio integrador como **Aprobado**, el estudiante deberá entregar un reporte técnico individual en PDF con la siguiente estructura:

1. **Diagrama de arquitectura:** Exportación en imagen del mapa visual creado en el Paso 1 mostrando patrones de resiliencia y distribución cloud.

2. **Evidencia de autocuración por infraestructura:**

    - Captura de pantalla de la terminal ejecutando `kubectl get pods -o wide` antes y después de forzar la eliminación del _Pod_ (`kubectl delete pod`).

    - Captura mostrando el nuevo _Pod_ generado automáticamente por el _ReplicaSet_ en estado `Running`.

3. **Evidencia de resiliencia por software (_Fallback_ activo):**

    - Captura del output en terminal de la ejecución del ciclo de peticiones en bash mostrando tanto las respuestas con código `SUCCESS` como las respuestas degradadas `DEGRADED_CACHE` sin ningún error `500 Internal Server Error`.

4. **Evidencia de comportamiento resiliente:**

- Captura o transcripción del momento en que el servicio cambia de una respuesta `SUCCESS` a una respuesta degradada `DEGRADED_CACHE`, explicando qué patrón de resiliencia entró en acción.

- Breve explicación de cómo los _health checks_, las réplicas y la distribución topológica aportan continuidad operativa aun cuando una instancia o dependencia falle.
