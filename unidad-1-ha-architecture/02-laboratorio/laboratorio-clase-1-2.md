# Laboratorio de la clase 1.2: Resiliencia en `catalog-service`

## Objetivo

Agregar patrones de tolerancia a fallos al servicio construido en el laboratorio 1.1 y comparar su comportamiento con la línea base.

## Punto de partida

Continúa en `02-laboratorio/proyecto-base-unidad-01/catalog-service`. No crees otro servicio. Antes de editar, confirma que `CatalogResource` todavía expone `/v1/products` y que tienes `availability-baseline.txt` del laboratorio anterior.

## Paso 1: Añadir la dependencia

Confirma en `pom.xml` la dependencia `quarkus-smallrye-fault-tolerance`. Ejecuta una compilación antes de continuar:

```bash
./mvnw test
```

## Paso 2: Implementar por etapas

Edita `src/main/java/com/ecom/catalog/CatalogResource.java`. Después de cada etapa, inicia la aplicación y repite al menos 20 solicitudes.

1. Añade `@Timeout(800)` al método `getProducts()`. Comprueba que la latencia simulada de 1200 ms deja de bloquear indefinidamente la solicitud.
2. Añade `@Retry(maxRetries = 2, delay = 150)`. Observa en los logs que una falla puede generar nuevos intentos.
3. Crea `getCatalogFallback()` y devuelve un JSON con `status` igual a `DEGRADED_CACHE`. Conecta el método con `@Fallback`.
4. Añade `@CircuitBreaker(requestVolumeThreshold = 4, failureRatio = 0.5, delay = 5000)`.

La combinación esperada es `Timeout`, `Retry`, `Fallback` y `CircuitBreaker`. No agregues `Bulkhead` en este laboratorio: se analiza conceptualmente porque `proyecto-base-unidad-01` no tiene un flujo concurrente aislado que permita evaluarlo de forma clara.

### Código Completo Final de `CatalogResource.java`

Una vez implementadas las 4 etapas, tu clase debe verse así:

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
    @Timeout(800)                                                    // Etapa 1: Timeout de 800ms
    @Retry(maxRetries = 2, delay = 150)                            // Etapa 2: Reintentos con delay
    @CircuitBreaker(requestVolumeThreshold = 4, 
                    failureRatio = 0.5, 
                    delay = 5000)                                   // Etapa 4: Circuit Breaker
    @Fallback(fallbackMethod = "getCatalogFallback")              // Etapa 3: Fallback
    public Response getProducts() throws InterruptedException {
        int chance = random.nextInt(10);

        // Simular latencia degradada en la base de datos (20% de probabilidad)
        if (chance < 2) {
            LOG.warning("Simulando latencia alta en consulta de catálogo...");
            Thread.sleep(1200);  // Esto será capturado por @Timeout(800)
        }

        // Simular falla de conexión a la base de datos (30% de probabilidad)
        if (chance >= 2 && chance < 5) {
            LOG.severe("Falla de conexión a la base de datos primaria.");
            throw new RuntimeException("Database connection timeout");
        }

        // Respuesta exitosa (50% de probabilidad)
        LOG.info("Catálogo retornado exitosamente desde la base de datos primaria.");
        return Response.ok(
            "{\"status\":\"SUCCESS\",\"data\":[\"Product A\",\"Product B\",\"Product C\"]}"
        ).build();
    }

    /**
     * Método de fallback invocado cuando:
     * - El @Timeout se activa (la solicitud tardó más de 800ms)
     * - El @CircuitBreaker se abre (demasiadas fallas detectadas)
     * - Ambos reintentos del @Retry fracasan
     */
    public Response getCatalogFallback() {
        LOG.info("Fallback activado: Sirviendo datos desde la memoria caché local.");
        return Response.ok(
            "{\"status\":\"DEGRADED_CACHE\",\"data\":[\"Cached Product A\",\"Cached Product B\"]}"
        ).build();
    }

    @GET
    @Path("/hello")
    @Produces(MediaType.TEXT_PLAIN)
    public String hello() {
        return "Catalog Service v1.0.0 - Unidad 1 - Alta Disponibilidad";
    }
}
```

**Puntos clave a verificar:**

- ✅ Las anotaciones están en el orden correcto (de arriba hacia abajo): `@Timeout` → `@Retry` → `@CircuitBreaker` → `@Fallback`
- ✅ El método `getCatalogFallback()` tiene el mismo nombre exacto que en `@Fallback(fallbackMethod = ...)`
- ✅ El método `getCatalogFallback()` retorna `Response` (mismo tipo que `getProducts()`)
- ✅ Los parámetros son los recomendados para testing: `Timeout(800)`, `Retry(maxRetries=2, delay=150)`, `CircuitBreaker(requestVolumeThreshold=4, failureRatio=0.5, delay=5000)`
- ✅ El código de simulación de latencia (`Thread.sleep(1200)`) y falla (`throw new RuntimeException()`) se mantienen sin cambios

---

## Paso 3: Validar los escenarios

En una terminal deja visibles los logs y, en otra, genera tráfico:

```bash
for i in {1..40}; do
    curl -sS -w ' | HTTP %{http_code} | tiempo %{time_total}s\n' http://localhost:8080/v1/products
done | tee resilience-sample.txt
```

Clasifica las respuestas:

```bash
grep -c '"status":"SUCCESS"' resilience-sample.txt || true
grep -c '"status":"DEGRADED_CACHE"' resilience-sample.txt || true
grep -c 'HTTP 200' resilience-sample.txt || true
```

Si no aparece `DEGRADED_CACHE`, repite la muestra. La simulación es aleatoria.

## Paso 4: Comparar contra la línea base

Compara `availability-baseline.txt` con `resilience-sample.txt` y responde:

- ¿Disminuyeron las respuestas HTTP `500`?
- ¿Qué porcentaje de respuestas continuó como `SUCCESS`?
- ¿Cuántas respuestas fueron `DEGRADED_CACHE`?
- ¿Qué costo tiene el `Retry` en latencia y llamadas adicionales?
- ¿Qué ocurre durante los cinco segundos en que el circuito permanece abierto?

## Qué debe observarse

- Respuestas `SUCCESS` con HTTP `200` (exitosas con datos reales).
- Respuestas `DEGRADED_CACHE` con HTTP `200` (éxito pero datos en caché, activadas por fallback).
- **Desaparición de errores HTTP `500`:** El `Timeout` + `Retry` + `CircuitBreaker` + `Fallback` evitan respuestas de error.
- Latencia variable: `Retry` introduce intentos adicionales que pueden aumentar la latencia observada.
- Después de 4-5 fallos en ventana de 10 solicitudes, el circuito se abre y todas las solicitudes subsecuentes retornan rápidamente con `DEGRADED_CACHE`.
- Los logs deben mostrar: `Simulando latencia alta...`, `Falla de conexión...`, y `Fallback activado...`.

## Guía de Troubleshooting

### Problema 1: Errores de compilación

**Síntoma:** `[ERROR] Failed to execute goal`

**Causa común:** La dependencia `quarkus-smallrye-fault-tolerance` no está en `pom.xml` o hay conflicto de versiones.

**Solución:**
```bash
./mvnw clean compile
./mvnw dependency:tree | grep -i fault
```

Asegúrate de que la versión de Quarkus en `pom.xml` es `3.38.0+` y que las anotaciones importadas son de `org.eclipse.microprofile.faulttolerance`.

### Problema 2: `@Fallback` no se invoca

**Síntoma:** No aparece `DEGRADED_CACHE` en las respuestas, solo `SUCCESS` o HTTP `500`.

**Causa común:** El método `getCatalogFallback()` no existe, tiene nombre incorrecto o retorna el tipo incorrecto.

**Solución:**
```java
@Fallback(fallbackMethod = "getCatalogFallback")  // ← Nombre exacto
public Response getProducts() { ... }

public Response getCatalogFallback() {  // ← Mismo nombre, retorna Response
    return Response.ok("{\"status\":\"DEGRADED_CACHE\",...}").build();
}
```

### Problema 3: `@CircuitBreaker` nunca se abre

**Síntoma:** El circuito permanece cerrado incluso con muchas fallas.

**Causa común:** El `requestVolumeThreshold` es muy alto o el `failureRatio` es muy bajo.

**Solución:** Usa valores bajos para testing:
```java
@CircuitBreaker(requestVolumeThreshold = 4, failureRatio = 0.5, delay = 5000)
```
Esto significa: "abre el circuito si en las últimas 4 solicitudes, al menos el 50% fallan".

### Problema 4: Latencia muy alta en logs

**Síntoma:** Los tiempos de respuesta son inconsistentes, mayores a 1200 ms.

**Causa común:** Los reintentos del `@Retry` están sumándose a la latencia.

**Solución:** Reduce el `delay` en `@Retry`:
```java
@Retry(maxRetries = 2, delay = 100)  // ← 100 ms entre reintentos
```

## Evidencia

Entrega el diff de `CatalogResource.java`, la compilación exitosa, ambas muestras y una tabla con `SUCCESS`, `DEGRADED_CACHE`, errores HTTP y latencia observada.

## Continuidad

El código resiliente que completes aquí será la entrada del laboratorio 1.3, donde se empaquetará y desplegará en Kubernetes.
