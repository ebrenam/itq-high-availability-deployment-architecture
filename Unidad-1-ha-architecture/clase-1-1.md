# 1.1 Fundamentos de Disponibilidad y Confiabilidad

Iniciamos la Unidad 1 estableciendo los cimientos teóricos y cuantitativos para entender por qué los sistemas fallan y cómo medimos su capacidad de mantenerse a flote antes de diseñar arquitecturas distribuidas.

## 1. Explicación conceptual

Cuando pasamos del desarrollo local en nuestra máquina a entornos productivos de escala masiva, la premisa fundamental cambia por completo: **todo lo que pueda fallar, fallará en algún momento**. En el paradigma _cloud-native_, la alta disponibilidad (_High Availability_ o HA) y la confiabilidad (_reliability_) no son propiedades accidentales del software, sino características arquitectónicas diseñadas explícitamente desde el primer día.

### Disponibilidad vs. confiabilidad

A menudo estos términos se usan como sinónimos, pero representan métricas distintas:

- **Disponibilidad (_availability_):** Es la proporción de tiempo que un sistema permanece funcional y accesible para responder a las peticiones de los usuarios. Se mide comúnmente en el porcentaje de "nueves" (ej. 99.9% o "tres nueves", lo que equivale a un máximo de ~8.76 horas de indisponibilidad al año).

- **Confiabilidad (_reliability_):** Es la probabilidad de que un sistema realice su función prevista de manera correcta y sin errores durante un período especificado bajo condiciones determinadas. Un sistema puede tener alta disponibilidad (responder siempre a las peticiones) pero baja confiabilidad (responder con un error `500 Internal Server Error`).

### Factores que afectan la disponibilidad

1. **Puntos únicos de fallo (_Single Points of Failure_ - SPOF):** Componentes individuales (un _load balancer_ no replicado, un único nodo de base de datos o un _switch_ de red) cuya falla provoca el colapso total del sistema.

2. **Saturación de recursos:** Agotamiento de CPU, memoria, sockets de red o _connection pools_ hacia la base de datos debido a picos inusuales de tráfico.

3. **Cascanueces de fallos o fallas en cascada (_cascading failures_):** Ocurre cuando la falla de un microservicio sobrecarga a los servicios vecinos que intentan reintentar peticiones descontroladamente (_retry storms_), provocando un efecto dominó.

4. **Despliegues y cambios operativos:** Errores humanos en la configuración, actualizaciones de código no probadas correctamente o falta de estrategias de _rollback_ automático.

### Principios de ingeniería de confiabilidad de sitios (SRE)

Pionera por Google, la disciplina de SRE (_Site Reliability Engineering_) aplica principios de ingeniería de software a la gestión de infraestructura y operaciones:

- **El abrazo al riesgo y los _error budgets_:** La disponibilidad del 100% no existe y intentar alcanzarla es prohibitivamente costoso e inhabilita la innovación. El _error budget_ (presupuesto de error) representa el margen permisible de fallas (100% - SLO). Mientras exista _error budget_, se pueden liberar características rápidamente; si se agota, se congelan los despliegues hasta estabilizar la plataforma.

- **Simplicidad y eliminación del _toil_:** Automatizar tareas repetitivas y manuales para enfocar la ingeniería en prevenir incidentes futuros.

- **Monitoreo orientado a la experiencia del usuario:** Monitorear desde la perspectiva del cliente (_user journey_) en lugar de simples métricas aisladas de servidor (como el uso de CPU).

### Métricas clave: SLI, SLO, SLA, MTTR, MTTF, MTBF

|**Métrica**|**Nombre completo**|**Descripción técnico-operativa**|
|---|---|---|
|**SLI**|_Service Level Indicator_|Medida cuantitativa en tiempo real del comportamiento de un servicio (ej. la latencia de respuesta o el porcentaje de peticiones exitosas `200 OK`).|
|**SLO**|_Service Level Objective_|La meta cuantitativa interna acordada por el equipo de ingeniería para un SLI (ej. "el 99.5% de las peticiones deben responder en menos de 200 ms durante 30 días").|
|**SLA**|_Service Level Agreement_|El contrato legal o compromiso comercial firmado con los usuarios finales. Define penalizaciones o desembolsos financieros si el SLO no se cumple. El SLA siempre es más permisivo que el SLO.|
|**MTTF**|_Mean Time to Failure_|Tiempo promedio que transcurre desde que un componente entra en operación hasta que sufre una falla irreparable. Aplica a componentes no reparables.|
|**MTTR**|_Mean Time to Repair_|Tiempo promedio requerido para diagnosticar, mitigar y resolver una falla una vez que se ha detectado. Reducir el MTTR es el objetivo primario en arquitecturas resilientes.|
|**MTBF**|_Mean Time Between Failures_|Tiempo promedio transcurrido entre dos fallas consecutivas en un sistema reparable ($\text{MTBF} = \text{MTTF} + \text{MTTR}$).|

$$\text{Disponibilidad} = \frac{\text{MTBF}}{\text{MTBF} + \text{MTTR}} \times 100$$

## 2. Analogía del mundo real

Imagina la cocina de un restaurante de alta cocina con una estrella Michelin durante la hora pico de un viernes.

- **SPOF (Punto único de fallo):** Hay un solo chef principal que supervisa la parrilla. Si se corta un dedo o se desmaya, toda la cocina se detiene por completo. Para evitar esto, se necesita un sistema con un _chef de respaldo_ (_active-passive_) o múltiples estaciones de parrilla funcionando simultáneamente (_active-active_).

- **SLI (_Service Level Indicator_):** Es el temporizador que mide cuántos minutos tarda cada platillo desde que se toma la orden hasta que llega a la mesa del cliente.

- **SLO (_Service Level Objective_):** El estándar de calidad que fijó el chef ejecutivo: _"El 95% de los platillos principales deben entregarse en menos de 18 minutos"_.

- **SLA (_Service Level Agreement_):** El compromiso del menú frente a los clientes: _"Si su comida tarda más de 35 minutos, el postre y la botella de vino van por cuenta de la casa"_.

- **MTTR (_Mean Time to Repair_):** Si a un cocinero se le quema una guarnición, ¿cuánto tiempo toma tirarla a la basura, limpiar el sartén y volver a preparar una guarnición nueva de reemplazo? Un tiempo de respuesta bajo mantiene al restaurante funcionando sin retrasos perceptibles.

- **Error Budget:** Si el equipo sabe que puede fallar en el 5% de las órdenes (su SLO es 95%), tienen margen de maniobra durante la semana para probar nuevos platillos en el menú. Pero si acumulan demasiados clientes insatisfechos a principio de mes, cancelan las pruebas culinarias y se apegan estrictamente a los platillos tradicionales hasta recuperar el margen.

## 3. Desglose técnico paso a paso

Para afianzar cómo aterrizamos los fundamentos de confiabilidad en código Java utilizando el framework **Quarkus**, construiremos un _health check_ y una medición básica de disponibilidad sin depender todavía de una plataforma completa de observabilidad.

### Paso 1: Configurar la aplicación Quarkus

En un proyecto Quarkus existente, asegurémonos de incluir las extensiones de observabilidad mediante el archivo `pom.xml`:

```xml
<dependencies>
    <!-- Extensión para Health Checks estándar (SmallRye Health) -->
    <dependency>
        <groupId>io.quarkus</groupId>
        <artifactId>quarkus-smallrye-health</artifactId>
    </dependency>
</dependencies>
```

### Paso 2: Crear un indicador de disponibilidad personalizado (_Health Check_)

Implementaremos una comprobación de estado para determinar la disponibilidad (_readiness probe_) simulando la conectividad de nuestro microservicio.

Crea el archivo `src/main/java/org/acme/reliability/DatabaseReadinessCheck.java`:

```java
package org.acme.reliability;

import org.eclipse.microprofile.health.HealthCheck;
import org.eclipse.microprofile.health.HealthCheckResponse;
import org.eclipse.microprofile.health.HealthCheckResponseBuilder;
import org.eclipse.microprofile.health.Readiness;
import jakarta.enterprise.context.ApplicationScoped;

@Readiness
@ApplicationScoped
public class DatabaseReadinessCheck implements HealthCheck {

    @Override
    public HealthCheckResponse call() {
        HealthCheckResponseBuilder responseBuilder = HealthCheckResponse.named("Database connection readiness");

        try {
            // Simulación de verificación de conectividad a la base de datos
            boolean databaseUp = checkDatabaseConnection();

            if (databaseUp) {
                return responseBuilder.up()
                        .withData("latency_ms", 12)
                        .withData("active_connections", 8)
                        .build();
            } else {
                return responseBuilder.down()
                        .withData("error", "Timeout connecting to DB pool")
                        .build();
            }
        } catch (Exception e) {
            return responseBuilder.down().withData("error", e.getMessage()).build();
        }
    }

    private boolean checkDatabaseConnection() {
        // En un entorno real, ejecutaría un "SELECT 1" rápido sobre el datasource
        return true; 
    }
}
```

### Paso 3: Simular solicitudes para medir disponibilidad básica

En esta unidad no necesitamos una plataforma completa de observabilidad. Nos basta con generar respuestas exitosas y fallidas para estimar manualmente un SLI de disponibilidad.

Crea la clase REST `src/main/java/org/acme/reliability/OrderResource.java`:

```java
package org.acme.reliability;

import jakarta.ws.rs.GET;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import java.util.Random;

@Path("/v1/orders")
public class OrderResource {

    private final Random random = new Random();

    @GET
    @Produces(MediaType.APPLICATION_JSON)
    public Response processOrder() {
        try {
            // Simular latencia variable
            int latency = random.nextInt(300);
            Thread.sleep(latency);

            // Simular una tasa de error inducida del 5%
            if (random.nextInt(100) < 5) {
                return Response.status(Response.Status.INTERNAL_SERVER_ERROR)
                        .entity("{\"error\": \"Order processing failed\"}").build();
            }

            return Response.ok("{\"status\": \"Order processed successfully\"}").build();

        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            return Response.serverError().build();
        }
    }
}
```

### Paso 4: Calcular un SLI manual de disponibilidad

Usaremos una medición simple basada en respuestas HTTP. Esto permite introducir el concepto de SLI sin depender todavía de Prometheus ni de Alertmanager.

Ejecuta una ráfaga de solicitudes y guarda el código HTTP de cada respuesta:

```bash
for i in {1..20}; do
    curl -s -o /dev/null -w "%{http_code}\n" http://localhost:8080/v1/orders
done > availability-sample.txt
```

Cuenta cuántas respuestas fueron exitosas (`200`) y cuántas fallaron:

```bash
SUCCESS=$(grep -c '^200$' availability-sample.txt)
TOTAL=$(wc -l < availability-sample.txt)

echo "scale=4; $SUCCESS / $TOTAL" | bc
```

El resultado representa una aproximación simple del SLI de disponibilidad para esa ventana de observación.

### Paso 5: Despliegue y verificación

1. Inicia la aplicación en modo desarrollo:

    ```bash
    ./mvnw quarkus:dev
    ```

2. Revisa el endpoint de salud (_Health Check_):

    ```bash
    curl -i http://localhost:8080/q/health/ready
    ```

3. Genera tráfico sobre la API para producir resultados medibles:

    ```bash
    for i in {1..20}; do curl -s http://localhost:8080/v1/orders; echo ""; done
    ```

4. Calcula la proporción de respuestas exitosas:

    ```bash
    SUCCESS=$(grep -c '^200$' availability-sample.txt)
    TOTAL=$(wc -l < availability-sample.txt)
    echo "Solicitudes exitosas: $SUCCESS de $TOTAL"
    ```

## 4. Reto de ingeniería o pregunta de reflexión

**El escenario:**

Un servicio de autenticación crítico procesa $1,000,000$ de solicitudes por día. El equipo de negocio definió un **SLO de disponibilidad del 99.9%** mensual para este servicio.

Durante una actualización de mantenimiento a mitad de mes, una mala configuración en el _connection pool_ causó un periodo de indisponibilidad total (_downtime_) que duró exactamente **45 minutos**.

**Para debatir en clase:**

1. ¿El equipo agotó el _error budget_ correspondiente a ese mes de 30 días? Muestra el cálculo matemático que respalda tu respuesta.

2. Si el tiempo de detección de la falla por las alertas (_Time to Detect_) fue de 5 minutos, ¿qué acciones de diseño de infraestructura o instrumentación de métricas implementarías para reducir el **MTTR** en el siguiente evento sin tocar el código fuente de Java?

> "En la sesión anterior analizamos cómo cuantificar la confiabilidad mediante métricas como SLI y SLO e identificar los puntos únicos de fallo, y ahora en esta sesión llevaremos ese conocimiento a la práctica al explorar patrones de diseño como circuit breaker, bulkhead y rate limiting para aislar y tolerar fallas de forma arquitectónica."
