# Laboratorio de la clase 1.2: Resiliencia en `catalog-service`

## Objetivo

Agregar patrones de tolerancia a fallos al servicio construido en el laboratorio 1.1 y comparar su comportamiento con la línea base.

## Punto de partida

Continúa en `02-laboratorio/proyecto-base/catalog-service`. No crees otro servicio. Antes de editar, confirma que `CatalogResource` todavía expone `/v1/products` y que tienes `availability-baseline.txt` del laboratorio anterior.

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

La combinación esperada es `Timeout`, `Retry`, `Fallback` y `CircuitBreaker`. No agregues `Bulkhead` en este laboratorio: se analiza conceptualmente porque el starter no tiene un flujo concurrente aislado que permita evaluarlo de forma clara.

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

## Evidencia

Entrega el diff de `CatalogResource.java`, la compilación exitosa, ambas muestras y una tabla con `SUCCESS`, `DEGRADED_CACHE`, errores HTTP y latencia observada.

## Continuidad

El código resiliente que completes aquí será la entrada del laboratorio 1.3, donde se empaquetará y desplegará en Kubernetes.
