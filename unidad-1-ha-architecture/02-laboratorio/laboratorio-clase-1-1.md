# Laboratorio de la clase 1.1: Línea base de disponibilidad

## Objetivo del laboratorio y escenario real

**El escenario:** Trabajas como _Junior Cloud Engineer_ en una plataforma e-commerce compuesta por `catalog-service`, `inventory-service`, `payment-service` y `orders-service`. Para esta primera unidad partirás de `proyecto-base-unidad-01`, un proyecto base mínimo donde `catalog-service` ya existe como primera pieza funcional del sistema.

Durante el último evento de ventas masivas, el servicio de catálogo colapsó por saturación de nodos y dependencia de una base de datos sin lectura replicada. La dirección de tecnología ha ordenado fortalecer esta primera pieza antes de seguir construyendo el resto de la plataforma.

**El objetivo:** Este laboratorio es el primero de tres partes. Ejecutarás el `catalog-service` inicial y medirás su comportamiento antes de añadir patrones de resiliencia. Esta medición será la referencia para comparar los resultados de los laboratorios 1.2 y 1.3.

**Regla de continuidad:** Completa este laboratorio antes de continuar con 1.2 y 1.3. Sin una línea base, no podrás validar el impacto de los patrones de resiliencia.

## Prerequisitos y stack tecnológico

Antes de iniciar, debes contar con las siguientes herramientas instaladas y funcionales en tu entorno de desarrollo:

### Requisitos comunes (Linux, macOS y Windows)

- **Java OpenJDK 25** y **Apache Maven 3.8+**.
- **Docker Engine** (v24.0+) o **Podman**.
- **Minikube** (v1.30+) o **Kind** (Kubernetes v1.28+) — opcional para este laboratorio, obligatorio para 1.3.
- **kubectl** configurado e interconectado con tu clúster local — opcional para este laboratorio, obligatorio para 1.3.
- **curl** o **Apache Bench (`ab`)** para generación de tráfico de prueba.

### Requisitos específicos por SO

![linux](images/linux.png) **Linux/macOS:**

- Terminal bash nativa
- Herramientas Unix: `grep`, `mktemp`, `wc`, `bc`

![win](images/windows.png) **Windows:**

- **PowerShell 5.0+** (recomendado) o **PowerShell Core** (pwsh)
  - Verifica tu versión: `$PSVersionTable.PSVersion`
  - Si tienes PowerShell < 5.0, actualiza desde [aquí](https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows)
- **curl** (incluido en Windows 10.1903+; si no lo tienes, usa el `curl.exe` del subsistema WSL o instala desde [curl.se](https://curl.se/download.html))

## Objetivo

Ejecutar el `catalog-service` inicial y medir su comportamiento antes de añadir patrones de resiliencia. Esta medición será la referencia para comparar los resultados de la clase 1.2.

## Punto de partida

Trabaja desde `02-laboratorio/proyecto-base-unidad-01/catalog-service`. Este proyecto base ya expone `/v1/products`, simula latencia alta y fallas de conexión, y contiene el health check base. Todavía no incluye `Timeout`, `Retry`, `Fallback` ni `CircuitBreaker`.

## Paso 1: Ejecutar la aplicación

> **⚠️ Nota Importante:** El endpoint expuesto puede responder de tres formas:
> - **HTTP 200 + JSON `SUCCESS`:** La solicitud fue exitosa (50% de probabilidad)
> - **HTTP 500 + RuntimeException:** Simulación de falla de BD (30% de probabilidad)
> - **Latencia alta (3000ms):** Simulación de congestión de BD (20% de probabilidad)


### ![linux](images/linux.png) Instrucciones para Linux/macOS

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

---

### ![win](images/windows.png) Instrucciones para Windows

En la Terminal 1 (PowerShell o CMD):

```powershell
cd unidad-1-ha-architecture\02-laboratorio\proyecto-base-unidad-01\catalog-service
.\mvnw.cmd quarkus:dev
```

> **Nota:** En PowerShell, si ves error de permisos de ejecución, ejecuta primero:
> ```powershell
> Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
> ```

En la Terminal 2 (PowerShell):

```powershell
curl -i http://localhost:8080/v1/products
```

> **Nota:** PowerShell en Windows 10.1903+ incluye `curl` como alias de `Invoke-WebRequest`.
> - Si quieres usar `curl.exe` directamente (versión nativa), asegúrate de que esté en `PATH`
> - Si `curl` no funciona, puedes remover el alias: `Remove-Item alias:curl`
> - Alternativa: Usa `Invoke-WebRequest -Uri http://localhost:8080/v1/products -Headers @{"User-Agent"="PowerShell"}`

---

### Consideraciones

> **📊 Nota pedagógica:** La latencia de 3 segundos es deliberadamente alta para que sea **muy obvia** cuando la veas en la salida. En el Paso 3, busca valores de `time_total` cercanos a `3.0` segundos. En el laboratorio 1.2, verás cómo el `@Timeout(800)` reduce eso a ~0.8 segundos, eliminando esos bloqueos largos.
>
**Es completamente normal** ver errores en algunas solicitudes. El servicio está simulando intencionalmente estos fallos para que midas su disponibilidad real sin patrones de resiliencia. En el **Paso 3**, ejecutarás 40 solicitudes consecutivas para captar esta distribución estadística completa.

## Paso 2: Revisar salud

```bash
curl -i http://localhost:8080/health
curl -i http://localhost:8080/ready
curl -i http://localhost:8080/live
```

Registra si cada endpoint responde `UP` o `DOWN`. En esta etapa, `/ready` simula una disponibilidad del 95%.

## Paso 3: Medir la línea base

### ![linux](images/linux.png) Instrucciones para Linux/macOS

Crea el archivo `test-availability.sh` con el siguiente contenido:

```bash
#!/bin/bash

# Script reutilizable para medir disponibilidad
# Genera 40 solicitudes, analiza y guarda resultados en availability-baseline.txt

OUTPUT_FILE="availability-baseline.txt"
ENDPOINT_URL="http://localhost:8080/v1/products"
NUM_REQUESTS=40

# 1. Limpiar archivo de salida
> "$OUTPUT_FILE"

echo "Ejecutando $NUM_REQUESTS solicitudes a $ENDPOINT_URL..."

# 2. Loop de solicitudes
for i in $(seq 1 "$NUM_REQUESTS"); do
    response_file=$(mktemp)
    metadata=$(curl -sS -o "$response_file" -w "%{http_code} %{time_total}" "$ENDPOINT_URL")
    body=$(cat "$response_file" | tr '\n' ' ')
    printf '%02d %s %s\n' "$i" "$metadata" "$body" | tee -a "$OUTPUT_FILE"
    rm -f "$response_file"
done

echo ""
echo "Resultados guardados en: $OUTPUT_FILE"
echo ""

# 3. Procesar métricas
SUCCESS=$(grep -c '"status":"SUCCESS"' "$OUTPUT_FILE" || true)
HTTP_200=$(grep -cE '^[0-9]+ 200 ' "$OUTPUT_FILE" || true)
HTTP_ERRORS=$(grep -cEv '^[0-9]+ 200 ' "$OUTPUT_FILE" || true)
TOTAL=$(wc -l < "$OUTPUT_FILE" | tr -d ' ')

if [[ $TOTAL -gt 0 ]]; then
    AVAILABILITY=$(echo "scale=4; $HTTP_200 / $TOTAL" | bc)
    echo "Respuestas SUCCESS: $SUCCESS"
    echo "Respuestas HTTP 200: $HTTP_200"
    echo "Respuestas HTTP distintas de 200: $HTTP_ERRORS"
    echo "Solicitudes totales: $TOTAL"
    echo "Disponibilidad observada: $AVAILABILITY"
fi
```

Luego hazlo ejecutable y ejecuta:

```bash
chmod +x test-availability.sh
./test-availability.sh
```

---

### ![win](images/windows.png) Instrucciones para Windows

Crea el archivo `test-availability.ps1` con el código adaptado a PowerShell:

```powershell
# 1. Definir y limpiar archivo de salida
$outputFile = "availability-baseline.txt"
if (Test-Path $outputFile) { Remove-Item $outputFile }

Write-Host "Ejecutando 40 solicitudes..." -ForegroundColor Cyan

# 2. Loop de 40 solicitudes
for ($i = 1; $i -le 40; $i++) {
    $tempFile = [System.IO.Path]::GetTempFileName()
    try {
        # Importante: usar curl.exe explícitamente en Windows
        $output = curl.exe -sS -o $tempFile -w "%{http_code} %{time_total}" http://localhost:8080/v1/products 2>$null
        
        $body = Get-Content -Raw -Path $tempFile 2>$null | ForEach-Object { $_ -replace "`r?`n", ' ' }
        
        $line = "{0:D2} {1} {2}" -f $i, $output, $body
        Add-Content -Path $outputFile -Value $line
        Write-Host $line
    }
    finally {
        Remove-Item -Force $tempFile -ErrorAction SilentlyContinue
    }
}

Write-Host "`nResultados guardados en: $outputFile`n" -ForegroundColor Green

# 3. Procesar métricas utilizando objetos de PowerShell en lugar de Regex frágiles
$lines = Get-Content $outputFile

$total = $lines.Count
$success = ($lines | Where-Object { $_ -like '*"status":"SUCCESS"*' }).Count
$http200 = ($lines | Where-Object { $_ -match '^\d+\s+200\s+' }).Count
$httpErrors = $total - $http200

# 4. Mostrar Resultados
Write-Host "Respuestas SUCCESS: $success"
Write-Host "Respuestas HTTP 200: $http200"
Write-Host "Respuestas HTTP distintas de 200: $httpErrors"
Write-Host "Solicitudes totales: $total"

if ($total -gt 0) {
    $availability = [math]::Round($http200 / $total, 4)
    Write-Host "Disponibilidad observada: $availability" -ForegroundColor Yellow
}
```

Luego ejecuta en PowerShell:

```powershell
.\test-availability.ps1
```

---

### Formato esperado de `availability-baseline.txt`

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
- **Algunos tiempos de respuesta muy altos (cerca de 3 segundos)** debido a la simulación de latencia — observa estos valores en la columna `time_total` del archivo resultante.
- **NO hay `DEGRADED_CACHE`:** Porque `proyecto-base-unidad-01` aún no tiene patrones de resiliencia

Esta línea base es tu referencia para comparar en el laboratorio 1.2. **Fija tu atención en los valores `time_total` cercanos a 3.0 segundos.**

- Respuestas `SUCCESS` con HTTP `200`.
- Algunas respuestas lentas por la simulación de 3000 ms (3 segundos) — esta latencia desaparecerá en 1.2 gracias a `@Timeout(800)`.
- Algunas respuestas HTTP `500` por la falla simulada de base de datos.
- No debe aparecer `DEGRADED_CACHE`, porque `proyecto-base-unidad-01` todavía no tiene `Fallback`.
- Los logs de la Terminal 1 deben explicar la causa de las respuestas lentas o fallidas.

## Guía de Troubleshooting

### Problema 1: `./mvnw quarkus:dev` no funciona

**Síntoma:** Error de permiso, comando no encontrado o error Maven.

![linux](images/linux.png) **Solución Linux/Mac:**

```bash
cd proyecto-base-unidad-01/catalog-service
chmod +x mvnw  # Asegurar que es ejecutable
./mvnw quarkus:dev
```

![win](images/windows.png) **Solución Windows:**

```powershell
cd proyecto-base-unidad-01\catalog-service
.\mvnw.cmd quarkus:dev
```

---

### Problema 2: Puerto 8080 ya está en uso

**Síntoma:** Error `Address already in use: bind`.

![linux](images/linux.png) **Solución Linux/macOS:**

```bash
# Identifica qué proceso usa el puerto 8080
lsof -i :8080

# Matar el proceso
kill -9 <PID>

# O cambiar puerto en Terminal 1
cd proyecto-base-unidad-01/catalog-service
./mvnw quarkus:dev -Dquarkus.http.port=9090
```

![win](images/windows.png) **Solución Windows (PowerShell):**

```powershell
# Identifica qué proceso usa el puerto 8080
netstat -noa | findstr :8080

# Matar el proceso (reemplaza PID con el número encontrado)
taskkill /PID <PID> /F

# O cambiar puerto en Terminal 1
cd proyecto-base-unidad-01\catalog-service
.\mvnw.cmd quarkus:dev -Dquarkus.http.port=9090

# Si cambias el puerto, actualiza las URLs de curl:
curl -i http://localhost:9090/v1/products
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

![linux](images/linux.png) **Solución Linux/macOS:** Ejecuta más solicitudes:

```bash
for i in {1..100}; do
    response_file=$(mktemp)
    metadata=$(curl -sS -o "$response_file" -w "%{http_code} %{time_total}" http://localhost:8080/v1/products)
    body=$(cat "$response_file" | tr '\n' ' ')
    printf '%03d %s %s\n' "$i" "$metadata" "$body"
    rm -f "$response_file"
done | tee availability-baseline-100.txt

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

![win](images/windows.png) **Solución Windows (PowerShell):** Modifica el script anterior (Paso 3) para 100 solicitudes:

```powershell
# Cambiar esta línea:
for ($i = 1; $i -le 40; $i++) {

# A esta:
for ($i = 1; $i -le 100; $i++) {

# Y guarda con un nuevo nombre:
$outputFile = "availability-baseline-100.txt"
```

Luego analiza con:

```powershell
$total = @(Get-Content availability-baseline-100.txt | Measure-Object -Line).Lines
$http200 = @(Select-String -Path availability-baseline-100.txt -Pattern '^\d+ 200 ' | Measure-Object).Count
$http500 = @(Select-String -Path availability-baseline-100.txt -Pattern '^\d+ 500 ' | Measure-Object).Count

Write-Host "Total: $total"
Write-Host "HTTP 200: $http200"
Write-Host "HTTP 500: $http500"
```

---

### Problema 5: Logs confusos o muy lentos

**Síntoma:** Los logs se imprimen lentamente o hay mucho ruido.

![linux](images/linux.png) **Solución Linux/macOS:**

```bash
./mvnw quarkus:dev -Dquarkus.log.level=WARN
```

![win](images/windows.png) **Solución Windows (PowerShell):**

```powershell
.\mvnw.cmd quarkus:dev -Dquarkus.log.level=WARN
```

Esto muestra solo WARNING y ERROR, ocultando DEBUG e INFO.

---

## Evidencia

Entrega la salida de `availability-baseline.txt`, los estados de `/health`, `/ready` y `/live`, y una breve interpretación de la latencia y los errores observados. Conserva esta evidencia para compararla con la clase 1.2.

## Continuidad

No modifiques todavía los manifiestos de Kubernetes. El siguiente laboratorio agregará los patrones de resiliencia sobre este mismo servicio.
