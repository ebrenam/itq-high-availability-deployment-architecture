# 📖 GLOSARIO: Unidad 1 — Términos Técnicos

## A

### **Active-Passive**

Arquitectura de alta disponibilidad donde un sistema principal activo (_primary_) recibe todo el tráfico, mientras un sistema secundario está en espera (_standby_). Si el primario falla, el secundario se activa. Menos eficiente en recursos que Active-Active, pero más simple de implementar.

**Ejemplo:** BD primaria en us-east-1a, réplica en standby en us-east-1b.

---

### **Active-Active**

Arquitectura de alta disponibilidad donde múltiples sistemas funcionan simultáneamente procesando tráfico en paralelo. Si uno falla, los demás absorben su carga.

**Ejemplo:** 3 pods de `catalog-service` atendiendo solicitudes simultáneamente.

---

### **Availability Zone (AZ)**

Uno o más centros de datos físicos independientes dentro de una región cloud, con alimentación eléctrica y conectividad de red propias. Las AZs dentro de una región están conectadas por redes de ultra baja latencia (<2ms).

**Ejemplo:** `us-east-1a`, `us-east-1b`, `us-east-1c` en la región AWS `us-east-1`.

---

### **Availability**

Porcentaje de tiempo que un sistema permanece funcional y accesible. Se mide en "nueves":

- 99.9% ("tres nueves") = ~8.76 horas de downtime/año
- 99.99% ("cuatro nueves") = ~52 minutos de downtime/año
- 99.999% ("cinco nueves") = ~5 minutos de downtime/año

**Fórmula:** Disponibilidad = MTBF / (MTBF + MTTR) × 100

---

## B

### **Backoff, Exponential**

Estrategia de espera progresiva entre reintentos. Cada reintento espera más que el anterior.

**Patrón:**

```text
1er intento falla → espera 100ms → reintento
2do intento falla → espera 200ms → reintento
3er intento falla → espera 400ms → reintento
```

Evita abrumar un servicio que está recuperándose.

---

### **Bulkhead**

Patrón de aislamiento inspirado en los mamparos de barcos. Divide recursos (thread pools, connection pools) en compartimentos aislados. Si un pool se agota, otros continúan funcionando.

**Beneficio:** Una base de datos lenta no paraliza el microservicio completo.

---

## C

### **Circuit Breaker**

Patrón de tolerancia a fallos que actúa como un interruptor eléctrico. Tiene 3 estados:

1. **Closed:** Funciona normalmente, todas las solicitudes pasan
2. **Open:** Se detectó un problema (muchas fallas), solicitudes fallan rápido sin intentar
3. **Half-Open:** Después de esperar, prueba si el servicio se recuperó

**En Lab 1.2:**

```java
@CircuitBreaker(
    requestVolumeThreshold = 4,  // Monitor cada 4 solicitudes
    failureRatio = 0.5,           // Si 50% fallan → abre circuito
    delay = 5000                  // Espera 5 segundos antes de half-open
)
```

---

### **CQRS (Command Query Responsibility Segregation)**

Patrón arquitectónico que separa operaciones de escritura (_commands_) de operaciones de lectura (_queries_). Permite escalar lectura y escritura de forma independiente.

**Ejemplo:** Escrituras van a BD primaria, lecturas se distribuyen entre réplicas de lectura.

---

## D

### **Degradation, Graceful**

Cuando un sistema no puede funcionar al 100%, continúa funcionando con funcionalidad reducida en lugar de colapsar completamente.

**Ejemplo:** `catalog-service` sin acceso a BD primaria devuelve datos cacheados con `status: DEGRADED_CACHE` en lugar de error 500.

---

### **Disaster Recovery (DR)**

Plan y proceso para recuperarse de fallas catastróficas (terremoto, incendio, etc.). Típicamente requiere múltiples regiones geográficas.

**Diferencia con HA:**

- **HA:** Tolera fallos dentro de una región (Active-Active)
- **DR:** Tolera fallos de regiones completas (multi-región)

---

## E

### **Error Budget**

Margen permisible de indisponibilidad antes de violar el SLO. Se calcula como:

Error Budget = 100% - SLO

**Ejemplo:** Si SLO = 99.5%, entonces Error Budget = 0.5% (30 minutos de downtime en 30 días).

Mientras exista Error Budget, puedes desplegar con frecuencia. Si se agota, congelas cambios hasta recuperarlo.

---

## F

### **Fallback**

Ruta alternativa que proporciona degradación elegante cuando falla la ruta principal.

**En Lab 1.2:**
```java
@Fallback(fallbackMethod = "getCatalogFallback")
public Response getProducts() { ... }

public Response getCatalogFallback() {
    return Response.ok("{\"status\":\"DEGRADED_CACHE\",...}").build();
}
```

---

### **Fault Tolerance**

Capacidad de un sistema para continuar funcionando incluso cuando componentes individuales fallan.

---

## H

### **Health Check**

Endpoint que verifica si un servicio está sano. En Kubernetes, hay 3 tipos:

1. **Startup Probe:** ¿Terminó de iniciar?
2. **Liveness Probe:** ¿Está vivo/respondiendo?
3. **Readiness Probe:** ¿Está listo para recibir tráfico?

**En Lab 1.3:**

```yaml
readinessProbe:
  httpGet:
    path: /ready
    port: 8080
  periodSeconds: 5
  failureThreshold: 2
```

---

## I

### **Idempotence**

Propiedad de una operación que produce el mismo resultado independientemente de cuántas veces se ejecute.

**Ejemplo:** "Crear usuario con ID=123" ejecutado 3 veces crea el usuario una sola vez (idempotente).

**Importancia:** Permite reintentos seguros sin efectos secundarios duplicados.

---

## J

### **Jitter**

Factor aleatorio sumado a tiempos de espera para desincronizar solicitudes concurrentes.

**Problema sin jitter:**

```text
Todos reintentan al mismo tiempo
→ Retry storm
→ Sobrecarga
```

**Solución con jitter:**

```text
Reintento 1: 100ms + random(0-50ms) = 120ms espera
Reintento 2: 200ms + random(0-100ms) = 240ms espera
Reintento 3: 400ms + random(0-200ms) = 520ms espera
```

---

## K

### **Kubernetes**

Orquestador de contenedores open-source que automatiza despliegue, escalado y recuperación de aplicaciones containerizadas.

**Capacidades relevantes a HA:**

- Despliegue multi-réplica automático
- Health checks y self-healing
- Rolling updates sin downtime
- Distribución topológica entre AZs

---

## L

### **Load Balancer**

Componente que distribuye tráfico entre múltiples instancias de un servicio.

**Tipos:**

- **Server-side:** Controlado por el proveedor cloud (AWS, GCP, Azure)
- **Client-side:** Embebido en el cliente (service mesh, proxies)

**Algoritmos:** Round Robin, Least Connections, IP Hash, Random.

---

### **Load Balancing, Global (GSLB)**

Distribución de tráfico entre múltiples regiones geográficas usando health checks y DNS routing.

**Ejemplo:** Usuario en México se redirige a `mx-region.example.com`, usuario en Brasil se redirige a `br-region.example.com`.

---

## M

### **Mean Time Between Failures (MTBF)**

Tiempo promedio transcurrido entre dos fallas consecutivas en un sistema reparable.

$$\text{MTBF} = \text{MTTF} + \text{MTTR}$$

---

### **Mean Time to Failure (MTTF)**

Tiempo promedio que funciona un componente antes de fallar por primera vez. Para componentes no reparables.

**Ejemplo:** Una vela dura ~40 horas antes de quemarse completamente → MTTF = 40 horas.

---

### **Mean Time to Repair (MTTR)**

Tiempo promedio requerido para detectar, diagnosticar y reparar una falla.

**Objetivo en HA:** Reducir MTTR mediante automatización (Kubernetes self-healing, health checks, alertas).

---

### **Microservices**

Arquitectura donde aplicaciones se componen de múltiples servicios independientes, cada uno responsable de una función de negocio.

**Ventaja para HA:** Falla de un servicio no arrastra los demás.

---

## N

### **N+1 Redundancy**

Tener N+1 instancias para soportar N. Permite tolerar falla de 1 instancia mientras las restantes absorben carga.

**Ejemplo:** 3 pods (N=2, +1 de redundancia) pueden fallar 1 y los 2 restantes siguen sirviendo.

---

## O

### **Observability**

Capacidad de inferir el estado interno de un sistema observando sus salidas (logs, métricas, traces).

**Diferencia con Monitoring:**

- **Monitoring:** Ver si algo está mal
- **Observability:** Entender por qué algo está mal

---

## P

### **Pod**

La unidad más pequeña deployable en Kubernetes. Típicamente un contenedor (aunque puede tener múltiples).

**En Lab 1.3:** Cada réplica del `catalog-service` es un Pod.

---

### **Probe, Health Check**

Verificación periódica ejecutada por Kubernetes para determinar si un Pod está sano.

**Tipos:**

- **Startup Probe:** Ha completado inicialización
- **Liveness Probe:** Está vivo (si falla, Kubernetes reinicia el Pod)
- **Readiness Probe:** Está listo para tráfico (si falla, se remueve de endpoints)

---

## R

### **Rate Limiting**

Patrón que limita la cantidad de solicitudes por cliente en una ventana de tiempo.

**Beneficio:** Protege contra picos de tráfico y ataques DoS.

**Ejemplo:** Máximo 100 solicitudes por minuto por cliente.

---

### **Reliability**

Probabilidad de que un sistema realice su función correctamente durante un período especificado.

**Diferencia con Availability:**

- **Disponibilidad:** ¿Está disponible? (Sí/No)
- **Confiabilidad:** ¿Es correcto lo que hace? (Exactitud)

**Ejemplo:** Un servicio puede estar disponible (respond) pero siendo no confiable (responde con errores).

---

### **Replica**

Copia de un servicio o dato. En Kubernetes, múltiples Pods son réplicas del mismo Deployment.

**Beneficio:** Si una réplica falla, las demás absorben tráfico sin interrupción.

---

### **Replica, Read**

Copia de una base de datos optimizada para lecturas. Los datos fluyen desde la BD primaria hacia las réplicas (replicación asíncrona).

**Beneficio:** Distribuir carga de lectura entre múltiples nodos.

---

### **Retry**

Estrategia de reintentar una operación fallida automáticamente.

**En Lab 1.2:**

```java
@Retry(maxRetries = 2, delay = 150)
```

Reintenta hasta 2 veces con espera de 150ms entre intentos.

**Importante:** Usar solo en operaciones idempotentes.

---

### **RTO (Recovery Time Objective)**

Meta para el tiempo máximo permitido de recuperación después de una falla.

**Ejemplo:** "Nuestro RTO es 5 minutos" = después de una falla, esperamos estar recuperados en máximo 5 minutos.

---

### **RPO (Recovery Point Objective)**

Meta para la máxima cantidad de datos que podemos perder en una falla.

**Ejemplo:** "Nuestro RPO es 1 hora" = podemos perder datos hasta 1 hora atrás (última réplica sincrónica).

---

## S

### **Saga Pattern**

Patrón para gestionar transacciones distribuidas a través de múltiples microservicios sin usar 2-Phase Commit.

**Mecanismo:** Secuencia de transacciones locales con eventos para coordinar. Si falla uno, ejecuta compensaciones.

---

### **SLA (Service Level Agreement)**

Contrato legal entre un proveedor de servicios y su cliente definiendo garantías de disponibilidad.

**Diferencia con SLO:**

- **SLO:** Meta interna del equipo de ingeniería
- **SLA:** Compromiso contractual con penalizaciones financieras

**Típicamente:** SLA es más permisivo que SLO (ej. SLO=99.5%, SLA=99.0%).

---

### **SLI (Service Level Indicator)**

Métrica cuantitativa del comportamiento real de un servicio.

**Ejemplos:**

- "99.5% de solicitudes retornaron HTTP 200"
- "Latencia P99 fue 200ms"
- "Disponibilidad fue 99.9%"

---

### **SLO (Service Level Objective)**

Meta interna para un SLI que el equipo de ingeniería se propone alcanzar.

**Ejemplo:** "Mantener 99.5% de solicitudes exitosas durante 30 días consecutivos".

---

### **SPOF (Single Point of Failure)**

Componente individual cuya falla provoca el colapso del sistema completo.

**Ejemplos:**

- Un único servidor web sin réplicas
- Un único router de red
- Una única BD primaria sin failover

**Objetivo HA:** Eliminar todos los SPOFs.

---

### **SRE (Site Reliability Engineering)**

Disciplina que aplica principios de ingeniería de software a infraestructura y operaciones.

**Conceptos clave:**

- Error budgets
- Monitoreo orientado a usuario
- Automatización del toil
- Simpleza operativa

---

## T

### **Timeout**

Límite de tiempo máximo para que una operación se complete. Si se excede, se cancela.

**En Lab 1.2:**

```java
@Timeout(800)  // Máximo 800 milliseconds
```

**Beneficio:** Evita esperas indefinidas por operaciones lentas.

---

### **Toil**

Trabajo manual, repetitivo y no escalable que no agrega valor al producto. En SRE, el objetivo es automatizar Toil para enfocarse en Engineering.

**Ejemplo:** Monitorear manualmente 100 servidores vs. usar alertas automáticas.

**En Lab 1.1:** Ejecutar 40 solicitudes manualmente sería Toil. Automatizarlo con un loop script es el camino hacia Engineering.

---

### **Topology Spread Constraint**

Regla en Kubernetes que obliga a distribuir Pods equitativamente entre nodos/AZs.

**En Lab 1.3:**

```yaml
topologySpreadConstraints:
  - maxSkew: 1
    topologyKey: topology.kubernetes.io/zone
    whenUnsatisfiable: ScheduleAnyway
```

**Beneficio:** Asegura que falla de una AZ no derriba todo el servicio.

---

## V

### **VPC (Virtual Private Cloud)**

Red privada en la nube donde despliegas recursos.

**Componentes:**

- Subredes públicas (expuestas a internet)
- Subredes privadas (aisladas de internet)
- Gateways, NATs, route tables

---

## Z

### **Zone, Availability**

Ver [Availability Zone](#availability-zone-az)

---

## 🔗 Referencias Cruzadas

**Conceptos relacionados a:**

- **Tolerancia a Fallos:** Fallback, Retry, Timeout, Circuit Breaker, Bulkhead
- **Replicación:** Replica, Read Replica, Active-Passive, Active-Active
- **Medición:** SLI, SLO, SLA, Availability, Reliability, MTTR, MTBF, MTTF
- **Infraestructura:** AZ, Region, VPC, Kubernetes, Pod, Load Balancer
- **Procesos:** SRE, Error Budget, Observability, RTO, RPO
