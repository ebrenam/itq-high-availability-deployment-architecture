# Laboratorio de la clase 1.1: Línea base de disponibilidad

## Objetivo del laboratorio y escenario real

**El escenario:** Trabajas como _Junior Cloud Engineer_ en una plataforma e-commerce compuesta por `catalog-service`, `inventory-service`, `payment-service` y `orders-service`. Para esta primera unidad partirás de `proyecto-base-unidad-01`, un proyecto base mínimo donde `catalog-service` ya existe como primera pieza funcional del sistema.

Durante el último evento de ventas masivas, el servicio de catálogo colapsó por saturación de nodos y dependencia de una base de datos sin lectura replicada. La dirección de tecnología ha ordenado fortalecer esta primera pieza antes de seguir construyendo el resto de la plataforma.

**El objetivo:** Este laboratorio es el primero de tres partes. Ejecutarás el `catalog-service` inicial y medirás su comportamiento antes de añadir patrones de resiliencia. Esta medición será la referencia para comparar los resultados de los laboratorios 1.2 y 1.3.

**Regla de continuidad:** Completa este laboratorio antes de continuar con 1.2 y 1.3. Sin una línea base, no podrás validar el impacto de los patrones de resiliencia.

## Prerequisitos y stack tecnológico

Antes de iniciar, debes contar con las siguientes herramientas instaladas y funcionales en tu entorno de desarrollo Linux/macOS:

- **Java OpenJDK 25** y **Apache Maven 3.8+**.
- **Docker Engine** (v24.0+) o **Podman**.
- **Minikube** (v1.30+) o **Kind** (Kubernetes v1.28+) — opcional para este laboratorio, obligatorio para 1.3.
- **kubectl** configurado e interconectado con tu clúster local — opcional para este laboratorio, obligatorio para 1.3.
- **curl** o **Apache Bench (`ab`)** para generación de tráfico de prueba.

## Objetivo

Ejecutar el `catalog-service` inicial y medir su comportamiento antes de añadir patrones de resiliencia. Esta medición será la referencia para comparar los resultados de la clase 1.2.

## Punto de partida

Trabaja desde `02-laboratorio/proyecto-base-unidad-01/catalog-service`. Este proyecto base ya expone `/v1/products`, simula latencia alta y fallas de conexión, y contiene el health check base. Todavía no incluye `Timeout`, `Retry`, `Fallback` ni `CircuitBreaker`.

## Paso 1: Ejecutar la aplicación

En la Terminal 1:

```bash
cd unidad-1-ha-architecture/02-laboratorio/proyecto-base-unidad-01/catalog-service
./mvnw quarkus:dev
```

En la Terminal 2, confirma que el endpoint responde:

> La opción -i (abreviación de --include) hace que curl muestre los headers HTTP de la respuesta junto con el cuerpo.

```bash
curl -i http://localhost:8080/v1/products
```

> **⚠️ Nota Importante:** Este endpoint puede responder de dos formas:
> - **HTTP 200 + JSON `SUCCESS`:** La solicitud fue exitosa (50% de probabilidad)
> - **HTTP 500 + RuntimeException:** Simulación de falla de BD (30% de probabilidad)
> - **Latencia alta (1200ms):** Simulación de congestión de BD (20% de probabilidad)
>
> **Es completamente normal** ver errores en algunas solicitudes. El servicio está simulando intencionalmente estos fallos para que midas su disponibilidad real sin patrones de resiliencia. En el **Paso 3**, ejecutarás 40 solicitudes consecutivas para captar esta distribución estadística completa.

## Paso 2: Revisar salud

```bash
curl -i http://localhost:8080/health
curl -i http://localhost:8080/ready
curl -i http://localhost:8080/live
```

Registra si cada endpoint responde `UP` o `DOWN`. En esta etapa, `/ready` simula una disponibilidad del 95%.

## Paso 3: Medir la línea base

Ejecuta una muestra de 40 solicitudes:

```bash
for i in {1..40}; do
    response_file=$(mktemp)
    metadata=$(curl -sS -o "$response_file" -w "%{http_code} %{time_total}" http://localhost:8080/v1/products)
    body=$(cat "$response_file" | tr '\n' ' ')
    printf '%02d %s %s\n' "$i" "$metadata" "$body"
    rm -f "$response_file"
done | tee availability-baseline.txt
```

Analiza los resultados:

```bash
SUCCESS=$(grep -c '"status":"SUCCESS"' availability-baseline.txt || true)
HTTP_200=$(grep -cE '^[0-9]+ 200 ' availability-baseline.txt || true)
HTTP_ERRORS=$(grep -cEv '^[0-9]+ 200 ' availability-baseline.txt || true)
TOTAL=$(wc -l < availability-baseline.txt | tr -d ' ')

echo "Solicitudes totales: $TOTAL"
echo "Respuestas SUCCESS: $SUCCESS"
echo "Respuestas HTTP 200: $HTTP_200"
echo "Respuestas HTTP distintas de 200: $HTTP_ERRORS"
echo "Disponibilidad observada: $(echo "scale=4; $HTTP_200 / $TOTAL" | bc)"
```

### Formato Esperado de `availability-baseline.txt`

Una vez ejecutado el comando de medición, tu archivo debe verse aproximadamente así (los valores numéricos pueden variar por la naturaleza aleatoria de la simulación):

```text
01 200 0.003881 {"status":"SUCCESS","data":["Product A","Product B","Product C"]}
02 200 1.203060 {"status":"SUCCESS","data":["Product A","Product B","Product C"]}
03 500 0.002877  500 - Internal Server Error ---------------------------  Details: 	Error id f4e6162e-a87a-422f-bfdb-9e9b49303ee6-67, java.lang.RuntimeException: Database connection timeout Decorate (Source code): 	Exception in CatalogResource.java:49 	  47          if (chance >= 2 && chance < 5) { 	  48              LOG.severe("Falla de conexión a la base de datos primaria."); 	→ 49              throw new RuntimeException("Database connection timeout"); 	  50          } 	  51   Stack: 	java.lang.RuntimeException: Database connection timeout 	at com.ecom.catalog.CatalogResource.getProducts(CatalogResource.java:49) 	at com.ecom.catalog.CatalogResource$quarkusrestinvoker$getProducts_1aa125a15c117f9554be0bd27ce943fec612c211.invoke(Unknown Source) 	at org.jboss.resteasy.reactive.server.handlers.InvocationHandler.handle(InvocationHandler.java:29) 	at io.quarkus.resteasy.reactive.server.runtime.QuarkusResteasyReactiveRequestContext.invokeHandler(QuarkusResteasyReactiveRequestContext.java:195) 	at org.jboss.resteasy.reactive.common.core.AbstractResteasyReactiveContext.run(AbstractResteasyReactiveContext.java:147) 	at io.quarkus.vertx.core.runtime.VertxCoreRecorder$15.runWith(VertxCoreRecorder.java:695) 	at org.jboss.threads.EnhancedQueueExecutor$Task.doRunWith(EnhancedQueueExecutor.java:2651) 	at org.jboss.threads.EnhancedQueueExecutor$Task.run(EnhancedQueueExecutor.java:2630) 	at org.jboss.threads.EnhancedQueueExecutor.runThreadBody(EnhancedQueueExecutor.java:1622) 	at org.jboss.threads.EnhancedQueueExecutor$ThreadBody.run(EnhancedQueueExecutor.java:1589) 	at org.jboss.threads.DelegatingRunnable.run(DelegatingRunnable.java:11) 	at org.jboss.threads.ThreadLocalResettingRunnable.run(ThreadLocalResettingRunnable.java:11) 	at io.netty.util.concurrent.FastThreadLocalRunnable.run(FastThreadLocalRunnable.java:30) 	at java.base/java.lang.Thread.run(Thread.java:1474) 
04 200 0.002456 {"status":"SUCCESS","data":["Product A","Product B","Product C"]}
05 200 0.001463 {"status":"SUCCESS","data":["Product A","Product B","Product C"]}
...
39 200 0.001512 {"status":"SUCCESS","data":["Product A","Product B","Product C"]}
40 200 0.001463 {"status":"SUCCESS","data":["Product A","Product B","Product C"]}
```

**Análisis esperado del output (comandos grep):**

> El resultado puede variar con cada ejecución.

```text
Solicitudes totales: 40
Respuestas SUCCESS: 26-30 (aprox.)
Respuestas HTTP 200: 26-30 (aprox.)
Respuestas HTTP distintas de 200: 10-14 (aprox.)
Disponibilidad observada: 0.65-0.75 (aprox.)
```

**Interpretación:**

- **Aproximadamente 65-70% de disponibilidad observada** (varía con cada ejecución debido a la naturaleza probabilística)
- **Aproximadamente 30-35% de errores HTTP 500** (varía con cada ejecución)
- Algunos tiempos de respuesta altos (cerca de 1.2 segundos) debido a la simulación de latencia
- **NO hay `DEGRADED_CACHE`:** Porque `proyecto-base-unidad-01` aún no tiene patrones de resiliencia

Esta línea base es tu referencia para comparar en el laboratorio 1.2.

- Respuestas `SUCCESS` con HTTP `200`.
- Algunas respuestas lentas por la simulación de 1200 ms.
- Algunas respuestas HTTP `500` por la falla simulada de base de datos.
- No debe aparecer `DEGRADED_CACHE`, porque `proyecto-base-unidad-01` todavía no tiene `Fallback`.
- Los logs de la Terminal 1 deben explicar la causa de las respuestas lentas o fallidas.

## Guía de Troubleshooting

### Problema 1: `./mvnw quarkus:dev` no funciona

**Síntoma:** Error de permiso, comando no encontrado o error Maven.

**Solución Linux/Mac:**

```bash
cd proyecto-base-unidad-01/catalog-service
chmod +x mvnw  # Asegurar que es ejecutable
./mvnw quarkus:dev
```

**Solución Windows:**

```powershell
cd proyecto-base-unidad-01\catalog-service
.\mvnw.cmd quarkus:dev
```

---

### Problema 2: Puerto 8080 ya está en uso

**Síntoma:** Error `Address already in use: bind`.

**Solución:**

```bash
# Identifica qué proceso usa el puerto 8080
lsof -i :8080  # Linux/Mac
netstat -ano | findstr :8080  # Windows

# Matar el proceso o usar otro puerto
# Matar proceso (Linux/Mac)
kill -9 <PID>

# O cambiar puerto en Terminal 1
cd proyecto-base-unidad-01/catalog-service
./mvnw quarkus:dev -Dquarkus.http.port=9090
```

---

### Problema 3: Endpoint `/v1/products` retorna 404

**Síntoma:** `curl http://localhost:8080/v1/products` retorna `404 Not Found`.

**Causa común:** El servicio tardó más de lo esperado en iniciar.

**Solución:**

```bash
# Espera más tiempo (Quarkus suele tardar 5-10 segundos)
# Verifica health check
curl -i http://localhost:8080/health

# Si retorna error, espera más segundos
# Luego intenta el endpoint nuevamente
curl -i http://localhost:8080/v1/products
```

---

### Problema 4: `availability-baseline.txt` tiene pocos errores

**Síntoma:** El archivo contiene principalmente `SUCCESS` y muy pocos errores HTTP `500`.

**Causa común:** La simulación es probabilística; con 40 solicitudes puede no capturar suficientes fallos.

**Solución:** Ejecuta más solicitudes:

```bash
for i in {1..100}; do
    response_file=$(mktemp)
    metadata=$(curl -sS -o "$response_file" -w "%{http_code} %{time_total}" http://localhost:8080/v1/products)
    body=$(cat "$response_file" | tr '\n' ' ')
    printf '%03d %s %s\n' "$i" "$metadata" "$body"
    rm -f "$response_file"
done | tee availability-baseline-100.txt

---

SUCCESS=$(grep -c '"status":"SUCCESS"' availability-baseline-100.txt || true)
HTTP_200=$(grep -cE '^[0-9]+ 200 ' availability-baseline-100.txt || true)
HTTP_ERRORS=$(grep -cEv '^[0-9]+ 200 ' availability-baseline-100.txt || true)
TOTAL=$(wc -l < availability-baseline-100.txt | tr -d ' ')

echo "Solicitudes totales: $TOTAL"
echo "Respuestas SUCCESS: $SUCCESS"
echo "Respuestas HTTP 200: $HTTP_200"
echo "Respuestas HTTP distintas de 200: $HTTP_ERRORS"
echo "Disponibilidad observada: $(echo "scale=4; $HTTP_200 / $TOTAL" | bc)"
```

Analiza estadísticas en la muestra más grande:

```bash
grep -c "200" availability-baseline-100.txt
grep -c "500" availability-baseline-100.txt
```

---

### Problema 5: Logs confusos o muy lentos

**Síntoma:** Los logs se imprimen lentamente o hay mucho ruido.

**Solución:** Reduce el nivel de logging:

```bash
./mvnw quarkus:dev -Dquarkus.log.level=WARN
```

Esto muestra solo WARNING y ERROR, ocultando DEBUG e INFO.

---

## Evidencia

Entrega la salida de `availability-baseline.txt`, los estados de `/health`, `/ready` y `/live`, y una breve interpretación de la latencia y los errores observados. Conserva esta evidencia para compararla con la clase 1.2.

## Continuidad

No modifiques todavía los manifiestos de Kubernetes. El siguiente laboratorio agregará los patrones de resiliencia sobre este mismo servicio.
