# Laboratorio de la clase 1.1: Línea base de disponibilidad

## Objetivo

Ejecutar el `catalog-service` inicial y medir su comportamiento antes de añadir patrones de resiliencia. Esta medición será la referencia para comparar los resultados de la clase 1.2.

## Punto de partida

Trabaja desde `02-laboratorio/proyecto-base/catalog-service`. El starter ya expone `/v1/products`, simula latencia alta y fallas de conexión, y contiene el health check base. Todavía no incluye `Timeout`, `Retry`, `Fallback` ni `CircuitBreaker`.

## Paso 1: Ejecutar la aplicación

En la Terminal 1:

```bash
cd Unidad-1-ha-architecture/02-laboratorio/proyecto-base/catalog-service
./mvnw quarkus:dev
```

En la Terminal 2, confirma que el endpoint responde:

```bash
curl -i http://localhost:8080/v1/products
```

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
    printf '%02d %s %s\n' "$i" "$metadata" "$(cat "$response_file")"
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

## Qué debe observarse

- Respuestas `SUCCESS` con HTTP `200`.
- Algunas respuestas lentas por la simulación de 1200 ms.
- Algunas respuestas HTTP `500` por la falla simulada de base de datos.
- No debe aparecer `DEGRADED_CACHE`, porque el starter todavía no tiene `Fallback`.
- Los logs de la Terminal 1 deben explicar la causa de las respuestas lentas o fallidas.

## Evidencia

Entrega la salida de `availability-baseline.txt`, los estados de `/health`, `/ready` y `/live`, y una breve interpretación de la latencia y los errores observados. Conserva esta evidencia para compararla con la clase 1.2.

## Continuidad

No modifiques todavía los manifiestos de Kubernetes. El siguiente laboratorio agregará los patrones de resiliencia sobre este mismo servicio.
