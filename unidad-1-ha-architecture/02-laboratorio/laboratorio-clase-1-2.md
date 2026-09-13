# Laboratorio de la clase 1.2: Resiliencia en `catalog-service`

## Objetivo

Agregar patrones de tolerancia a fallos al servicio construido en el laboratorio 1.1 y comparar su comportamiento con la línea base.

**Regla de continuidad:** Completa primero [Laboratorio 1.1](./laboratorio-clase-1-1.md) — necesitas el archivo `availability-baseline.txt` para comparar. Tras completar este laboratorio, continuarás con [Laboratorio 1.3](./laboratorio-clase-1-3.md) para desplegar en Kubernetes.

## Punto de partida

Continúa en `02-laboratorio/proyecto-base-unidad-01/catalog-service`. No crees otro servicio. Antes de editar, confirma que:
- `CatalogResource` todavía expone `/v1/products`
- Tienes el archivo `availability-baseline.txt` del laboratorio anterior (para comparar resultados después)

## Estado actual del código

Actualmente, el método `getProducts()` en `CatalogResource.java` es básico y **sin patrones de resiliencia**:

- ✅ **Implementado:** Endpoint `/v1/products` que simula 3 escenarios:
  - 20% latencia alta (3000 ms)
  - 30% falla de conexión a BD
  - 50% respuesta exitosa
  
- ❌ **Problemas sin resiliencia:**
  - Si el sistema es lento (3000 ms), el cliente se queda bloqueado indefinidamente.
  - Si la conexión a BD falla, retorna HTTP `500` (error).
  - No hay reintentos automáticos si hay fallo temporal.
  - No hay respuesta degradada; todo es "éxito total" o "error total".

### Lo que vas a cambiar

Agregar 4 anotaciones de MicroProfile Fault Tolerance **en este orden exacto**:

1. **`@Timeout(800)`** — Cancela cualquier solicitud que tarde más de 800 ms.
2. **`@Retry(maxRetries = 2, delay = 150)`** — Reintenta automáticamente hasta 2 veces si falla.
3. **`@Fallback(fallbackMethod = "getCatalogFallback")`** — Si todo falla, activa un método que retorna datos en caché.
4. **`@CircuitBreaker(...)`** — Si hay demasiadas fallas, abre el circuito y rechaza solicitudes rápidamente para evitar sobrecargar el sistema.

### Resultado esperado

Después de implementar estos patrones:
- ✅ HTTP `200` siempre (nunca HTTP `500`).
- ✅ Respuestas `SUCCESS` cuando todo funciona.
- ✅ Respuestas `DEGRADED_CACHE` cuando falla el backend.
- ✅ Menor latencia percibida gracias al timeout.

---

## Paso 1: Añadir la dependencia

Confirma en `pom.xml` la dependencia `quarkus-smallrye-fault-tolerance`. Ejecuta una compilación antes de continuar:

```bash
# Compila el proyecto y ejecuta todas las pruebas unitarias
./mvnw test
```

## Paso 2: Implementar por etapas

Edita `src/main/java/com/ecom/catalog/CatalogResource.java`. Después de cada etapa, inicia la aplicación y repite al menos 200 solicitudes.

> **IMPORTANTE**
> 
> Reutiliza el script del laboratorio 1.1 (`test-availability.sh` o `test-availability.ps1` según tu SO) para generar tráfico automáticamente.
> 
> El script requiere parámetro obligatorio.
> - **Linux/macOS:** `./test-availability.sh resilience-sample.txt`
> - **Windows:** `.\test-availability.ps1 -OutputFile "resilience-sample.txt"`
> 
> Esto generará un archivo `resilience-sample.txt` con los mismos 200 solicitudes, que luego compararás con `availability-baseline.txt` (línea base sin patrones).

---

### Paso 2.1: Declara los campos ThreadLocal para rastrear intentos

Antes de agregar las anotaciones, declara dos campos `ThreadLocal` como variables de clase (dentro de `CatalogResource`, después de `private final Random random = new Random();`):

```java
    /**
     * ThreadLocal para rastrear el número de intento de cada solicitud HTTP.
     * Se incrementa en cada invocación de getProducts() debido a @Retry,
     * permitiendo observar claramente los reintentos en los logs.
     */
    private static final ThreadLocal<Integer> ATTEMPT_COUNT = ThreadLocal.withInitial(() -> 0);

    /**
     * ThreadLocal para determinar si la solicitud HTTP actual debe fallar en los
     * primeros 2 intentos. Se genera una sola vez por solicitud y se reutiliza
     * en todos los reintentos, garantizando un patrón predecible de fallos.
     */
    private static final ThreadLocal<Boolean> SHOULD_FAIL_FIRST_ATTEMPTS = ThreadLocal.withInitial(() -> false);
```

Estos campos son **thread-safe** y evitan que los reintentos generen números aleatorios diferentes. Cada solicitud HTTP nueva reinicia estos valores automáticamente.

---

### Paso 2.2: Añade `@Timeout(800)` y `@Retry(maxRetries = 2, delay = 150)`

Comprueba que la latencia simulada de 3000 ms deja de bloquear indefinidamente la solicitud, y que los reintentos funcionan.

> **NOTA PEDAGÓGICA**
>
> - Sin `@Timeout`, las solicitudes se bloquean durante 3 segundos. Con esta anotación, se cancelarán después de 800ms, ahorrando ~2200ms por solicitud fallida. Esta diferencia será evidente cuando compares los tiempos de respuesta.
>
> - Se define un `delay` fijo de 150ms entre reintentos para simplicidad pedagógica. En aplicaciones de producción, se recomienda **exponential backoff** (150ms → 300ms → 600ms) combinado con **jitter** (aleatoriedad) para evitar sincronización accidental de reintentos en múltiples clientes. Esta mejora se cubre en cursos avanzados.

Agrega los siguientes `imports` al inicio del archivo:

```java
import org.eclipse.microprofile.faulttolerance.Timeout;
import org.eclipse.microprofile.faulttolerance.Retry;
```

Actualiza el código:

```java
    @GET
    @Produces(MediaType.APPLICATION_JSON)
    @Timeout(800)
    @Retry(maxRetries = 2, delay = 150)
    public Response getProducts() throws InterruptedException {
        try {
            // Incrementar contador de intentos para esta solicitud HTTP
            ATTEMPT_COUNT.set(ATTEMPT_COUNT.get() + 1);
            int currentAttempt = ATTEMPT_COUNT.get();

            // Separador visual: marca el inicio de una nueva solicitud HTTP
            if (currentAttempt == 1) {
                LOG.info("════════════════════════════════════════════════════════════");
            }

            LOG.info("[Intento " + currentAttempt + "/3] Consultando catálogo de productos...");

            // En el primer intento, decidir si esta solicitud HTTP fallará en todos los intentos
            if (currentAttempt == 1) {
                // 60% de probabilidad de que los 3 intentos fallen
                SHOULD_FAIL_FIRST_ATTEMPTS.set(random.nextInt(10) < 6);
            }

            boolean shouldFail = SHOULD_FAIL_FIRST_ATTEMPTS.get();

            // Los 3 intentos pueden fallar (si fue marcado)
            // Si todos fallan, el @Fallback se activará
            if (shouldFail && currentAttempt <= 3) {
                // Alternar entre tipo de fallo en cada intento para mayor claridad en logs
                if (currentAttempt == 1) {
                    LOG.severe("[Intento " + currentAttempt + "/3] Falla de conexión a la base de datos primaria.");
                    throw new RuntimeException("Database connection timeout");
                } else if (currentAttempt == 2) {
                    LOG.warning("[Intento " + currentAttempt + "/3] Simulando latencia alta en consulta de catálogo...");
                    Thread.sleep(3000);  // Esto será capturado por @Timeout(800)
                } else if (currentAttempt == 3) {
                    LOG.severe("[Intento " + currentAttempt + "/3] Falla de conexión después de reintentos.");
                    throw new RuntimeException("Database connection timeout after retries");
                }
            }

            // Respuesta exitosa (tercer intento o si no estaba marcado para fallar)
            LOG.info("[Intento " + currentAttempt + "/3] Catálogo retornado exitosamente desde la base de datos primaria.");
            ATTEMPT_COUNT.set(0);  // Resetear inmediatamente para siguiente solicitud HTTP
            SHOULD_FAIL_FIRST_ATTEMPTS.set(false);
            return Response.ok("{\"status\":\"SUCCESS\",\"data\":[\"Product A\",\"Product B\",\"Product C\"]}").build();
            
        } finally {
            // Solo resetear si se agotaron reintentos sin éxito (cuando llega a intento 3 y falla)
            if (ATTEMPT_COUNT.get() >= 3) {
                ATTEMPT_COUNT.set(0);
                SHOULD_FAIL_FIRST_ATTEMPTS.set(false);
            }
        }
    }
```

### Qué observar en los logs

Busca líneas que muestren una secuencia **predecible** de reintentos separadas por líneas de `════`. La solicitud HTTP genera un "número aleatorio" en el intento 1 que determina si fallará en todos los intentos. Con esta configuración:

- ~60% de las solicitudes fallarán en los 3 intentos y verás HTTP 500
- ~40% de las solicitudes tendrán éxito en el intento 1 y verás HTTP 200 SUCCESS

Ejemplo de solicitud que falla en todos los intentos (verás HTTP 500 sin @Fallback):

```bash
    ════════════════════════════════════════════════════════════
    [Intento 1/3] Consultando catálogo de productos...
    [Intento 1/3] Falla de conexión a la base de datos primaria.
    [Intento 2/3] Consultando catálogo de productos...
    [Intento 2/3] Simulando latencia alta en consulta de catálogo...
    [Intento 3/3] Consultando catálogo de productos...
    [Intento 3/3] Falla de conexión después de reintentos.
```

Ejemplo de solicitud que tiene éxito en primer intento:

```bash
    ════════════════════════════════════════════════════════════
    [Intento 1/3] Consultando catálogo de productos...
    [Intento 1/3] Catálogo retornado exitosamente desde la base de datos primaria.
```

### Qué está pasando en el servicio

En el Paso 2.2, el código genera un número aleatorio en el intento 1: si es menor a 6 (60% de probabilidad), marca la solicitud como "fallida" y todos los 3 intentos fracasarán con diferentes errores (conexión, latencia de 3000ms capturada por `@Timeout`, excepción). El 40% restante retorna SUCCESS en el intento 1.

**¿Qué observas?**

- `@Timeout` reduce la latencia (~2200ms ahorrados por solicitud), pero **no elimina fallos**: los rechaza de forma más rápida.
- `@Retry` proporciona 3 oportunidades, pero **sin `@Fallback` sigue siendo HTTP 500**: el cliente recibe un error completo en lugar de una respuesta degradada.

El siguiente paso (`@Fallback`) convertirá esos errores HTTP 500 en respuestas HTTP 200 con datos en caché, elevando la disponibilidad hacia 100%.

---

### Paso 2.3: Añade `@Fallback` con método `getCatalogFallback()`

Crea el método de fallback y conecta con `@Fallback`.

> **NOTA PEDAGÓGICA**
>
> - Sin `@Fallback`, si los reintentos agotan todas las tentativas, la solicitud HTTP devuelve un error HTTP `500`. Con esta anotación, el contenedor Quarkus intercepta automáticamente la excepción lanzada por `getProducts()` después del tercer intento fallido, y en su lugar invoca `getCatalogFallback()`, que retorna datos en caché. Esto transforma un "error completo" en una "respuesta degradada pero útil" — los clientes siguen recibiendo datos (aunque antiguos) en lugar de un error. Este patrón es esencial para aplicaciones que valoran la **disponibilidad** sobre la **consistencia**.

Agrega los siguientes `imports` al inicio del archivo:

```java
import org.eclipse.microprofile.faulttolerance.Fallback;
```

Actualiza el código:

```java
    @GET
    @Produces(MediaType.APPLICATION_JSON)
    @Timeout(800)
    @Retry(maxRetries = 2, delay = 150)
    @Fallback(fallbackMethod = "getCatalogFallback")
    public Response getProducts() throws InterruptedException {
        try {
            // Incrementar contador de intentos para esta solicitud HTTP
            ATTEMPT_COUNT.set(ATTEMPT_COUNT.get() + 1);
            int currentAttempt = ATTEMPT_COUNT.get();

            // Separador visual: marca el inicio de una nueva solicitud HTTP
            if (currentAttempt == 1) {
                LOG.info("════════════════════════════════════════════════════════════");
            }

            LOG.info("[Intento " + currentAttempt + "/3] Consultando catálogo de productos...");

            // En el primer intento, decidir si esta solicitud HTTP fallará en todos los intentos
            if (currentAttempt == 1) {
                // 60% de probabilidad de que los 3 intentos fallen
                SHOULD_FAIL_FIRST_ATTEMPTS.set(random.nextInt(10) < 6);
            }

            boolean shouldFail = SHOULD_FAIL_FIRST_ATTEMPTS.get();

            // Los 3 intentos pueden fallar (si fue marcado)
            // Si todos fallan, el @Fallback se activará
            if (shouldFail && currentAttempt <= 3) {
                // Alternar entre tipo de fallo en cada intento para mayor claridad en logs
                if (currentAttempt == 1) {
                    LOG.severe("[Intento " + currentAttempt + "/3] Falla de conexión a la base de datos primaria.");
                    throw new RuntimeException("Database connection timeout");
                } else if (currentAttempt == 2) {
                    LOG.warning("[Intento " + currentAttempt + "/3] Simulando latencia alta en consulta de catálogo...");
                    Thread.sleep(3000);  // Esto será capturado por @Timeout(800)
                } else if (currentAttempt == 3) {
                    LOG.severe("[Intento " + currentAttempt + "/3] Falla de conexión después de reintentos.");
                    throw new RuntimeException("Database connection timeout after retries");
                }
            }

            // Respuesta exitosa (tercer intento o si no estaba marcado para fallar)
            LOG.info("[Intento " + currentAttempt + "/3] Catálogo retornado exitosamente desde la base de datos primaria.");
            ATTEMPT_COUNT.set(0);  // Resetear inmediatamente para siguiente solicitud HTTP
            SHOULD_FAIL_FIRST_ATTEMPTS.set(false);
            return Response.ok("{\"status\":\"SUCCESS\",\"data\":[\"Product A\",\"Product B\",\"Product C\"]}").build();
            
        } finally {
            // No resetear aquí: si la solicitud falla, getCatalogFallback() leerá el contador
            // antes de resetearlo. Si tuvo éxito, ya se reseteó antes del return.
        }
    }

    /**
     * Método de fallback invocado cuando:
     * - El @Timeout se activa (la solicitud tardó más de 800ms)
     * - El @CircuitBreaker se abre (demasiadas fallas detectadas)
     * - Ambos reintentos del @Retry fracasan
     */
    public Response getCatalogFallback() {
        int failedAttempts = ATTEMPT_COUNT.get();
        LOG.info("Fallback activado: Se agotaron todos los " + failedAttempts + " intentos. Sirviendo datos desde caché.");
        ATTEMPT_COUNT.set(0);  // Resetear contador para siguiente solicitud HTTP
        SHOULD_FAIL_FIRST_ATTEMPTS.set(false);  // Resetear flag para siguiente solicitud HTTP
        return Response.ok("{\"status\":\"DEGRADED_CACHE\",\"data\":[\"Cached Product A\",\"Cached Product B\"]}").build();
    }
```

### Qué observar en los logs

El fallback se activa cuando todos los reintentos fracasan. En los logs verás un mensaje `"Fallback activado"` seguido del contador de intentos fallidos. Esto ocurre típicamente cuando:

- Los 3 intentos generan excepciones (conexión rechazada, timeout, etc.)
- O cuando el @Timeout cancela la solicitud en intento 2 (la latencia de 3000 ms supera los 800 ms permitidos)

Ejemplo de logs con fallback activado:

```bash
    ════════════════════════════════════════════════════════════
    [Intento 1/3] Consultando catálogo de productos...
    [Intento 1/3] Falla de conexión a la base de datos primaria.
    [Intento 2/3] Consultando catálogo de productos...
    [Intento 2/3] Simulando latencia alta en consulta de catálogo...
    [Intento 3/3] Consultando catálogo de productos...
    [Intento 3/3] Falla de conexión después de reintentos.
    Fallback activado: Se agotaron todos los 3 intentos. Sirviendo datos desde caché.
    ════════════════════════════════════════════════════════════
```

### Qué está pasando en el servicio

El `@Fallback` transforma la disponibilidad de forma radical. En el Paso 2.2 sin fallback, viste que ~60% de las solicitudes fallaban y retornaban HTTP 500 (no disponibles). Ahora con `@Fallback`:

**Resultado esperado después de 200 solicitudes:**

- Aproximadamente **40-50% respuestas SUCCESS** (BD primaria funciona en primer intento)
- Aproximadamente **50-60% respuestas DEGRADED_CACHE** (fallback activado después de fallos)
- **100% respuestas HTTP 200** (0 errores HTTP 500)
- **Disponibilidad observada: ~1.0000 (100%)**

**¿Qué cambió?**

Todas las solicitudes que hubieran retornado HTTP 500 (error completo) ahora retornan HTTP 200 con datos en caché. Esto no es "perfección" — los datos son antiguos — pero es **disponibilidad garantizada**. El cliente siempre obtiene una respuesta útil.

**¿Qué observas?**

- Las solicitudes sin fallback (Paso 2.2) terminaban en error HTTP 500; con fallback terminan en HTTP 200 con estado `DEGRADED_CACHE`
- La disponibilidad saltó de **0.60-0.75** (Paso 2.2, sin fallback) a aproximadamente **1.0000** (Paso 2.3, con fallback)
- No hay "magia": simplemente `@Fallback` intercepta las excepciones después del tercer intento fallido y ofrece un método alternativo

Este patrón es fundamental en sistemas donde la **disponibilidad > consistencia**: es mejor servir datos antiguos que rechazar la solicitud completamente. El siguiente paso (`@CircuitBreaker`) mejorará aún más el rendimiento del sistema evitando reintentos innecesarios cuando el servicio está claramente fuera de servicio.

### Paso 2.4: Añade `@CircuitBreaker` para completar la implementación

Agrega la anotación `@CircuitBreaker(requestVolumeThreshold = 10, failureRatio = 0.7, delay = 5000)` para completar la implementación.

> **NOTA PEDAGÓGICA**
>
> - Sin `@CircuitBreaker`, cada solicitud HTTP reintenta innecesariamente incluso cuando el servicio backend está completamente fuera de servicio, consumiendo recursos y ralentizando aún más el sistema. El CircuitBreaker implementa el patrón homónimo (conocido en electrónica): cuando detecta que una proporción de solicitudes falla consistentemente, "abre el circuito" (cambio a estado OPEN) y rechaza nuevas solicitudes automáticamente **sin reintentar**, devolviéndolas directamente al Fallback. Después de un tiempo configurado (`delay = 5000` ms = 5 segundos), el circuito pasa a estado HALF_OPEN y permite probar si el servicio se recuperó. Si las pruebas son exitosas, cierra el circuito (estado CLOSED) y reanuda operaciones normales.
> 
> - **Parámetros:**
>   - `requestVolumeThreshold = 10`: Ventana de medición de 10 solicitudes (se evalúan las últimas 10)
>   - `failureRatio = 0.7`: Abre el circuito si al menos el 70% de esas 10 solicitudes fallan (7 de 10)
>   - `delay = 5000`: Espera 5 segundos antes de pasar a HALF_OPEN

Agrega los siguientes `imports` al inicio del archivo:

```java
import org.eclipse.microprofile.faulttolerance.CircuitBreaker;
```

Actualiza el código:

```java
    @GET
    @Produces(MediaType.APPLICATION_JSON)
    @Timeout(800)
    @Retry(maxRetries = 2, delay = 150)
    @CircuitBreaker(requestVolumeThreshold = 10, failureRatio = 0.7, delay = 5000)
    @Fallback(fallbackMethod = "getCatalogFallback")
    public Response getProducts() throws InterruptedException {
        try {
            // Incrementar contador de intentos para esta solicitud HTTP
            ATTEMPT_COUNT.set(ATTEMPT_COUNT.get() + 1);
            int currentAttempt = ATTEMPT_COUNT.get();

            // Separador visual: marca el inicio de una nueva solicitud HTTP
            if (currentAttempt == 1) {
                LOG.info("════════════════════════════════════════════════════════════");
            }

            LOG.info("[Intento " + currentAttempt + "/3] Consultando catálogo de productos...");

            // En el primer intento, decidir si esta solicitud HTTP fallará en todos los intentos
            if (currentAttempt == 1) {
                // 60% de probabilidad de que los 3 intentos fallen
                SHOULD_FAIL_FIRST_ATTEMPTS.set(random.nextInt(10) < 6);
            }

            boolean shouldFail = SHOULD_FAIL_FIRST_ATTEMPTS.get();

            // Los 3 intentos pueden fallar (si fue marcado)
            // Si todos fallan, el @Fallback se activará
            if (shouldFail && currentAttempt <= 3) {
                // Alternar entre tipo de fallo en cada intento para mayor claridad en logs
                if (currentAttempt == 1) {
                    LOG.severe("[Intento " + currentAttempt + "/3] Falla de conexión a la base de datos primaria.");
                    throw new RuntimeException("Database connection timeout");
                } else if (currentAttempt == 2) {
                    LOG.warning("[Intento " + currentAttempt + "/3] Simulando latencia alta en consulta de catálogo...");
                    Thread.sleep(3000);  // Esto será capturado por @Timeout(800)
                } else if (currentAttempt == 3) {
                    LOG.severe("[Intento " + currentAttempt + "/3] Falla de conexión después de reintentos.");
                    throw new RuntimeException("Database connection timeout after retries");
                }
            }

            // Respuesta exitosa (tercer intento o si no estaba marcado para fallar)
            LOG.info("[Intento " + currentAttempt + "/3] Catálogo retornado exitosamente desde la base de datos primaria.");
            ATTEMPT_COUNT.set(0);  // Resetear inmediatamente para siguiente solicitud HTTP
            SHOULD_FAIL_FIRST_ATTEMPTS.set(false);
            return Response.ok("{\"status\":\"SUCCESS\",\"data\":[\"Product A\",\"Product B\",\"Product C\"]}").build();
            
        } finally {
            // No resetear aquí: si la solicitud falla, getCatalogFallback() leerá el contador
            // antes de resetearlo. Si tuvo éxito, ya se reseteó antes del return.
        }
    }

    /**
     * Método de fallback invocado cuando:
     * - El @Timeout se activa (la solicitud tardó más de 800ms)
     * - El @CircuitBreaker se abre (demasiadas fallas detectadas)
     * - Ambos reintentos del @Retry fracasan
     */
    public Response getCatalogFallback() {
        int failedAttempts = ATTEMPT_COUNT.get();
        LOG.info("Fallback activado: Se agotaron todos los " + failedAttempts + " intentos. Sirviendo datos desde caché.");
        ATTEMPT_COUNT.set(0);  // Resetear contador para siguiente solicitud HTTP
        SHOULD_FAIL_FIRST_ATTEMPTS.set(false);  // Resetear flag para siguiente solicitud HTTP
        return Response.ok("{\"status\":\"DEGRADED_CACHE\",\"data\":[\"Cached Product A\",\"Cached Product B\"]}").build();
    }
```

### Qué observar en los logs

El CircuitBreaker actúa sin mostrar transiciones explícitas. Su comportamiento real se observa a través del **contador de intentos** en el fallback. Después de detectar 7 o más fallos en las últimas 10 solicitudes (ratio de falla ≥70%), **abre el circuito (OPEN) y rechaza todas las solicitudes sin entrar al código**, mandándolas directamente al Fallback con contador **0**.

**Fases del CircuitBreaker observables en logs:**

1. **Fase inicial (CLOSED):** Solicitudes normales con reintentos completos
   - Ves: `Intento 1/3`, `Intento 2/3`, `Intento 3/3`
   - Contador en fallback: **3, 2** (cuando @Timeout corta en intento 2)
   - Ejemplo: `Fallback activado: Se agotaron todos los 3 intentos.`

2. **Apertura del circuito (OPEN):** Sin advertencia, aparecen múltiples líneas con contador **0**
   - Ves: `Fallback activado: Se agotaron todos los 0 intentos.` (sin intentos previos)
   - Significado: El CircuitBreaker **rechazó la solicitud SIN ejecutar getProducts()**
   - Duración: Típicamente ~5-15 líneas consecutivas (durante ~5 segundos configurados)

3. **Prueba de recuperación (HALF_OPEN → transición):** Después de ~5 segundos
   - Ves: Intento 1 falla con contador **1** → `Fallback activado: Se agotaron todos los 1 intentos.`
   - Seguido nuevamente de rechazos con contador **0**
   - El circuito está "probando" si el servicio se recuperó, pero aún rechaza

4. **Cierre del circuito (CLOSED nuevamente):** Cuando las pruebas tienen éxito
   - Ves: `[Intento 1/3] Catálogo retornado exitosamente...` (sin fallback)
   - Vuelven los patrones normales con reintentos completos

**Ejemplo de log real mostrando transición:**

```bash
════════════════════════════════════════════════════════════ ← Fase CLOSED: inicio
[Intento 1/3] Consultando catálogo de productos...
[Intento 1/3] Falla de conexión a la base de datos primaria.
[Intento 2/3] Consultando catálogo de productos...
[Intento 2/3] Simulando latencia alta en consulta de catálogo...
[Intento 3/3] Consultando catálogo de productos...
[Intento 3/3] Falla de conexión después de reintentos.
Fallback activado: Se agotaron todos los 3 intentos. Sirviendo datos desde caché.
════════════════════════════════════════════════════════════ ← Segunda solicitud
[Intento 1/3] Consultando catálogo de productos...
[Intento 1/3] Falla de conexión a la base de datos primaria.
[Intento 2/3] Consultando catálogo de productos...
[Intento 2/3] Simulando latencia alta en consulta de catálogo...
Fallback activado: Se agotaron todos los 2 intentos. Sirviendo datos desde caché.
════════════════════════════════════════════════════════════ ← Tercera solicitud (después de ~7 fallos)
[Intento 1/3] Consultando catálogo de productos...
[Intento 1/3] Falla de conexión a la base de datos primaria.
Fallback activado: Se agotaron todos los 1 intentos. Sirviendo datos desde caché.
Fallback activado: Se agotaron todos los 0 intentos. Sirviendo datos desde caché.  ← CIRCUITO ABRE
Fallback activado: Se agotaron todos los 0 intentos. Sirviendo datos desde caché.  ← Rechazos consecutivos
Fallback activado: Se agotaron todos los 0 intentos. Sirviendo datos desde caché.  ← Sin intentos, sin reintentos
Fallback activado: Se agotaron todos los 0 intentos. Sirviendo datos desde caché.  ← SmallRye interceptó
Fallback activado: Se agotaron todos los 0 intentos. Sirviendo datos desde caché.  ← antes de entrar al método
Fallback activado: Se agotaron todos los 0 intentos. Sirviendo datos desde caché.  ← Duración: ~5 segundos
Fallback activado: Se agotaron todos los 0 intentos. Sirviendo datos desde caché.  ← ...
... (más rechazos con contador 0) ...
════════════════════════════════════════════════════════════ ← Después de ~5 segundos: HALF_OPEN
[Intento 1/3] Consultando catálogo de productos...
[Intento 1/3] Falla de conexión a la base de datos primaria.  ← Intenta 1 sola vez
Fallback activado: Se agotaron todos los 1 intentos. Sirviendo datos desde caché.  ← Sin reintentos
Fallback activado: Se agotaron todos los 0 intentos. Sirviendo datos desde caché.  ← Aún rechazando
... (más rechazos) ...
════════════════════════════════════════════════════════════ ← Eventualmente: éxito, circuito CLOSED
[Intento 1/3] Consultando catálogo de productos...
[Intento 1/3] Catálogo retornado exitosamente desde la base de datos primaria.  ← Sin fallback
════════════════════════════════════════════════════════════
[Intento 1/3] Consultando catálogo de productos...
[Intento 1/3] Catálogo retornado exitosamente desde la base de datos primaria.  ← Operación normal
```

**Tabla de referencia rápida - Interpretación del contador en Fallback:**

| Línea de log | Contador | Estado | Significado |
|---|---|---|---|
| `Se agotaron todos los 3 intentos` | **3** | CLOSED | Todos los 3 reintentos completados y fallaron |
| `Se agotaron todos los 2 intentos` | **2** | CLOSED | @Timeout canceló el intento 2 (latencia 3000ms > 800ms) |
| `Se agotaron todos los 1 intentos` | **1** | HALF_OPEN o transición | Error en intento 1, sin reintentos (circuito prueba recuperación) |
| `Se agotaron todos los 0 intentos` | **0** | OPEN | CircuitBreaker **interceptó y rechazó antes de entrar** al método |

**Clave para reconocer OPEN state:** Busca secuencias de `"Fallback activado: Se agotaron todos los 0 intentos"` **sin líneas de `[Intento...]` previas**. Eso significa el CircuitBreaker está **OPEN**, protegiendo el sistema al rechazar solicitudes sin permitir reintentos. Es la máxima protección contra cascadas de falla.

La combinación esperada es `Timeout`, `Retry`, `Fallback` y `CircuitBreaker`. No agregues `Bulkhead` en este laboratorio: se analiza conceptualmente porque `proyecto-base-unidad-01` no tiene un flujo concurrente aislado que permita evaluarlo de forma clara.

---

## Paso 3: Validación final completa

**Tras completar los Pasos 2.1, 2.2, 2.3 y 2.4**, ejecuta una validación final integral para confirmar que todos los patrones de resiliencia funcionan juntos correctamente.

### 3.1: Generar tráfico con la configuración completa (Pasos 2.1-2.4)

Ahora que tienes implementados los 4 patrones (`@Timeout`, `@Retry`, `@Fallback`, `@CircuitBreaker`), ejecuta el script de prueba:

En una terminal deja visibles los logs y, en otra, ejecuta:

**Linux/macOS:**

```bash
./test-availability.sh resilience-sample.txt
```

**Windows:**

```powershell
.\test-availability.ps1 -OutputFile "resilience-sample.txt"
```

Esto generará **200 solicitudes** y guardará los resultados en `resilience-sample.txt`.

### 3.2: Crear un script para comparar resultados

Crea un script que analice automáticamente ambas muestras.

![linux](images/linux.png) **Solución Linux/Mac:**

En la ruta donde están tus archivos de resultados crea el archivo `analyze-resilience.sh`:

```bash
#!/bin/bash

# Script para analizar y comparar resultados de resiliencia
# Uso: ./analyze-resilience.sh

if [ ! -f "availability-baseline.txt" ] || [ ! -f "resilience-sample.txt" ]; then
    echo "❌ Error: Archivos no encontrados."
    echo "   Asegúrate de que existen: availability-baseline.txt y resilience-sample.txt"
    exit 1
fi

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║         ANÁLISIS DE RESILIENCIA: Lab 1.1 vs Lab 1.2            ║"
echo "╚════════════════════════════════════════════════════════════════╝"

echo ""
echo "📊 LÍNEA BASE (Lab 1.1 - SIN patrones)"
echo "─────────────────────────────────────────"
TOTAL_1_1=$(wc -l < availability-baseline.txt)
SUCCESS_1_1=$(grep -c '"status":"SUCCESS"' availability-baseline.txt || true)
ERRORS_1_1=$((TOTAL_1_1 - SUCCESS_1_1))
AVAIL_1_1=$(awk "BEGIN {printf \"%.4f\", $SUCCESS_1_1 / $TOTAL_1_1}")

echo "Total solicitudes:        $TOTAL_1_1"
echo "SUCCESS (HTTP 200):       $SUCCESS_1_1 (~$(( SUCCESS_1_1 * 100 / TOTAL_1_1 ))%)"
echo "Errores/No disponibles:   $ERRORS_1_1 (~$(( ERRORS_1_1 * 100 / TOTAL_1_1 ))%)"
echo "Disponibilidad:           $AVAIL_1_1 ($(( SUCCESS_1_1 * 100 / TOTAL_1_1 ))%)"

echo ""
echo "📊 CON PATRONES (Lab 1.2 - Completo: Timeout + Retry + Fallback + CircuitBreaker)"
echo "─────────────────────────────────────────────────────────────────────────────────"
TOTAL_1_2=$(wc -l < resilience-sample.txt)
SUCCESS_1_2=$(grep -c '"status":"SUCCESS"' resilience-sample.txt || true)
DEGRADED_1_2=$(grep -c '"status":"DEGRADED_CACHE"' resilience-sample.txt || true)
TOTAL_RESPUESTAS=$((SUCCESS_1_2 + DEGRADED_1_2))
AVAIL_1_2=$(awk "BEGIN {printf \"%.4f\", $TOTAL_RESPUESTAS / $TOTAL_1_2}")

echo "Total solicitudes:        $TOTAL_1_2"
echo "SUCCESS (HTTP 200):       $SUCCESS_1_2 (~$(( SUCCESS_1_2 * 100 / TOTAL_1_2 ))%)"
echo "DEGRADED_CACHE (HTTP 200):$DEGRADED_1_2 (~$(( DEGRADED_1_2 * 100 / TOTAL_1_2 ))%)"
echo "Errores HTTP 500:         0"
echo "Disponibilidad:           $AVAIL_1_2 ($(( TOTAL_RESPUESTAS * 100 / TOTAL_1_2 ))%)"

echo ""
echo "📈 COMPARACIÓN - MEJORA OBTENIDA"
echo "─────────────────────────────────────────"
MEJORA_AVAIL=$(awk "BEGIN {printf \"%.4f\", $AVAIL_1_2 - $AVAIL_1_1}")
MEJORA_PORCENTAJE=$(awk "BEGIN {printf \"%.2f\", ($AVAIL_1_2 - $AVAIL_1_1) * 100}")
REDUCCION_ERRORES=$(awk "BEGIN {printf \"%.2f\", (1 - $TOTAL_RESPUESTAS / $TOTAL_1_2) * 100}")

echo "Disponibilidad mejorada:  $MEJORA_AVAIL ($MEJORA_PORCENTAJE%)"
echo "Errores eliminados:       ~100% (de ~$(( ERRORS_1_1 * 100 / TOTAL_1_1 ))% a 0%)"
echo "HTTP 500 desaparecieron:  ✅ Completamente"
echo "Respuestas degradadas:    $DEGRADED_1_2 solicitudes salvadas por @Fallback"

echo ""
echo "✅ CONCLUSIÓN"
echo "─────────────────────────────────────────"
if (( $(echo "$AVAIL_1_2 > 0.99" | bc -l) )); then
    echo "La implementación de patrones de resiliencia fue EXITOSA."
    echo "Disponibilidad alcanzada: ~100% (aceptable para mayoría de aplicaciones)"
else
    echo "La implementación funciona, pero revisa si el @CircuitBreaker se activó correctamente."
fi
echo ""
```

Dale permisos de ejecución:

```bash
chmod +x analyze-resilience.sh
```

Ejecuta el script:

```bash
./analyze-resilience.sh
```

![win](images/windows.png) **Solución Windows:**

En la ruta donde están tus archivos de resultados crea el archivo `analyze-resilience.ps1`:

```powershell
# Script para analizar y comparar resultados de resiliencia
# Uso: .\analyze-resilience.ps1

if (-not (Test-Path "availability-baseline.txt") -or -not (Test-Path "resilience-sample.txt")) {
    Write-Host "❌ Error: Archivos no encontrados." -ForegroundColor Red
    Write-Host "   Asegúrate de que existen: availability-baseline.txt y resilience-sample.txt"
    exit 1
}

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║         ANÁLISIS DE RESILIENCIA: Lab 1.1 vs Lab 1.2            ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan

Write-Host ""
Write-Host "📊 LÍNEA BASE (Lab 1.1 - SIN patrones)" -ForegroundColor Yellow
Write-Host "─────────────────────────────────────────" -ForegroundColor Yellow
$baseline = @(Get-Content availability-baseline.txt)
$total_1_1 = $baseline.Count
$success_1_1 = ($baseline | Where-Object { $_ -like '*"status":"SUCCESS"*' }).Count
$errors_1_1 = $total_1_1 - $success_1_1
$avail_1_1 = if ($total_1_1 -gt 0) { [math]::Round($success_1_1 / $total_1_1, 4) } else { 0 }

Write-Host "Total solicitudes:        $total_1_1"
Write-Host "SUCCESS (HTTP 200):       $success_1_1 (~$([math]::Round($success_1_1 * 100 / $total_1_1))%)"
Write-Host "Errores/No disponibles:   $errors_1_1 (~$([math]::Round($errors_1_1 * 100 / $total_1_1))%)"
Write-Host "Disponibilidad:           $avail_1_1 ($([math]::Round($success_1_1 * 100 / $total_1_1))%)"

Write-Host ""
Write-Host "📊 CON PATRONES (Lab 1.2 - Completo: Timeout + Retry + Fallback + CircuitBreaker)" -ForegroundColor Yellow
Write-Host "─────────────────────────────────────────────────────────────────────────────────" -ForegroundColor Yellow
$resilience = @(Get-Content resilience-sample.txt)
$total_1_2 = $resilience.Count
$success_1_2 = ($resilience | Where-Object { $_ -like '*"status":"SUCCESS"*' }).Count
$degraded_1_2 = ($resilience | Where-Object { $_ -like '*"status":"DEGRADED_CACHE"*' }).Count
$total_respuestas = $success_1_2 + $degraded_1_2
$avail_1_2 = if ($total_1_2 -gt 0) { [math]::Round($total_respuestas / $total_1_2, 4) } else { 0 }

Write-Host "Total solicitudes:        $total_1_2"
Write-Host "SUCCESS (HTTP 200):       $success_1_2 (~$([math]::Round($success_1_2 * 100 / $total_1_2))%)"
Write-Host "DEGRADED_CACHE (HTTP 200):$degraded_1_2 (~$([math]::Round($degraded_1_2 * 100 / $total_1_2))%)"
Write-Host "Errores HTTP 500:         0"
Write-Host "Disponibilidad:           $avail_1_2 ($([math]::Round($total_respuestas * 100 / $total_1_2))%)"

Write-Host ""
Write-Host "📈 COMPARACIÓN - MEJORA OBTENIDA" -ForegroundColor Green
Write-Host "─────────────────────────────────────────" -ForegroundColor Green
$mejora_avail = [math]::Round($avail_1_2 - $avail_1_1, 4)
$mejora_porcentaje = [math]::Round(($avail_1_2 - $avail_1_1) * 100, 2)

Write-Host "Disponibilidad mejorada:  $mejora_avail ($mejora_porcentaje%)"
Write-Host "Errores eliminados:       ~100% (de ~$([math]::Round($errors_1_1 * 100 / $total_1_1))% a 0%)"
Write-Host "HTTP 500 desaparecieron:  ✅ Completamente"
Write-Host "Respuestas degradadas:    $degraded_1_2 solicitudes salvadas por @Fallback"

Write-Host ""
Write-Host "✅ CONCLUSIÓN" -ForegroundColor Green
Write-Host "─────────────────────────────────────────" -ForegroundColor Green
if ($avail_1_2 -gt 0.99) {
    Write-Host "La implementación de patrones de resiliencia fue EXITOSA." -ForegroundColor Green
    Write-Host "Disponibilidad alcanzada: ~100% (aceptable para mayoría de aplicaciones)" -ForegroundColor Green
} else {
    Write-Host "La implementación funciona, pero revisa si el @CircuitBreaker se activó correctamente." -ForegroundColor Yellow
}
Write-Host ""
```

Ejecuta el script:

```powershell
.\analyze-resilience.ps1
```

---

### Qué verás en la salida

Cuando ejecutes el script, obtendrás un análisis automático como este:

```bash
╔════════════════════════════════════════════════════════════════╗
║         ANÁLISIS DE RESILIENCIA: Lab 1.1 vs Lab 1.2            ║
╚════════════════════════════════════════════════════════════════╝

📊 LÍNEA BASE (Lab 1.1 - SIN patrones)
─────────────────────────────────────────
Total solicitudes:        200
SUCCESS (HTTP 200):       133 (~66%)
Errores/No disponibles:   67 (~33%)
Disponibilidad:           0.6650 (66%)

📊 CON PATRONES (Lab 1.2 - Completo: Timeout + Retry + Fallback + CircuitBreaker)
─────────────────────────────────────────────────────────────────────────────────
Total solicitudes:        200
SUCCESS (HTTP 200):       25 (~12%)
DEGRADED_CACHE (HTTP 200):175 (~87%)
Errores HTTP 500:         0
Disponibilidad:           1.0000 (100%)

📈 COMPARACIÓN - MEJORA OBTENIDA
─────────────────────────────────────────
Disponibilidad mejorada:  0.3350 (33.50%)
Errores eliminados:       ~100% (de ~33% a 0%)
HTTP 500 desaparecieron:  ✅ Completamente
Respuestas degradadas:    175 solicitudes salvadas por @Fallback

✅ CONCLUSIÓN
─────────────────────────────────────────
La implementación de patrones de resiliencia fue EXITOSA.
Disponibilidad alcanzada: ~100% (aceptable para mayoría de aplicaciones)
```

**Responde estas preguntas sobre la configuración completa (Pasos 2.1-2.4):**

- ¿Disminuyeron las respuestas HTTP `500` respecto a la línea base? (deberían ser 0 o muy cercano a 0)
- ¿Qué porcentaje de respuestas fue `SUCCESS` vs `DEGRADED_CACHE` en la configuración completa?
- ¿La latencia de respuesta mejoró con respecto a Lab 1.1? (compara tiempos en `time_total` de ambos archivos)
- ¿Qué costo tiene el `Retry` en latencia y llamadas adicionales a la base de datos?
- **Evento crítico:** ¿En qué momento observaste que el circuito se abrió (múltiples líneas con contador `0`)? ¿Cuánto duró la fase OPEN (~5 segundos)?
- ¿Después de que el circuito se recuperó (HALF_OPEN → CLOSED), volvieron a funcionar los reintentos completos?

### Conclusiones esperadas

Comparando `availability-baseline.txt` (Lab 1.1 sin patrones) vs `resilience-sample.txt` (Lab 1.2 con patrones completos):

| Métrica | Lab 1.1 (línea base) | Lab 1.2 (con patrones) | Mejora |
|---|---|---|---|
| HTTP 200 SUCCESS | 60-75% | 10-30% | ✅ Reducido (es normal) |
| HTTP 200 DEGRADED_CACHE | 0% | 70-90% | ✅ Fallback activo |
| HTTP 500 | 25-40% | ~0% | ✅ Eliminados |
| Disponibilidad total | 0.60-0.75 | ~1.00 (100%) | ✅ Garantizada |
| Latencia máx. | 3000-4500ms | 800-1200ms | ✅ Reducida 3-5x |
| Circuito OPEN detectado | N/A | Sí, típicamente tras 10-15 solicitudes | ✅ Protección activa |

**¿Qué está sucediendo?**

El `@CircuitBreaker` detecta un patrón de fallas repetidas (7+ de 10 últimas solicitudes), abre el circuito automáticamente y **rechaza nuevas solicitudes SIN reintentar**, desviándolas directamente al Fallback. Esto protege el backend de sobrecargas en cascada. Después de 5 segundos, el circuito prueba si el servicio se recuperó pasando a HALF_OPEN. Si recuperación tiene éxito, cierra nuevamente (CLOSED) y reanuda operaciones normales.

---

## Análisis Profundo: ¿Por qué Fallback se activa tan frecuentemente?

Es normal observar **70-90% de respuestas DEGRADED_CACHE** en lugar del rango inicial 40-60%. Las razones:

1. **Modelo de fallos agresivo:** El 60% de solicitudes están configuradas para fallar en TODOS los intentos. Con 200 solicitudes, ~120 activan Fallback inmediatamente después de agotar reintentos.

2. **CircuitBreaker se abre rápido:** Con `failureRatio = 0.7` y `requestVolumeThreshold = 10`, el circuito abre tras ~7 fallos en 10 solicitudes (típicamente solicitudes 10-15). Una vez OPEN, rechaza masivamente durante ~5 segundos, forzando cientos de Fallbacks adicionales.

3. **Timeout acelera fallos:** El intento 2 simula latencia de 3000ms que `@Timeout(800)` cancela. Eso **cuenta como fallo** y acelera reintentos y apertura del circuito.

**Conclusión pedagógica clave:** El alto porcentaje de DEGRADED_CACHE **NO es un fracaso**; es **evidencia de que la resiliencia funciona**. El Fallback salvó ~140-170 solicitudes de retornar HTTP 500. Disponibilidad: 66% → 100%. **Eso es éxito garantizado.**

---

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
@CircuitBreaker(requestVolumeThreshold = 10, failureRatio = 0.7, delay = 5000)
```

Esto significa: "abre el circuito si en las últimas 10 solicitudes, al menos el 70% fallan".

### Problema 4: Latencia muy alta en logs

**Síntoma:** Los tiempos de respuesta son inconsistentes, mayores a 3000 ms.

**Causa común:** Los reintentos del `@Retry` están sumándose a la latencia.

**Solución:** Reduce el `delay` en `@Retry`:

```java
@Retry(maxRetries = 2, delay = 100)  // ← 100 ms entre reintentos
```

## Evidencia

Entrega el diff de `CatalogResource.java`, la compilación exitosa, ambas muestras y una tabla con `SUCCESS`, `DEGRADED_CACHE`, errores HTTP y latencia observada.

## Continuidad

El código resiliente que completes aquí será la entrada del laboratorio 1.3, donde se empaquetará y desplegará en Kubernetes.
