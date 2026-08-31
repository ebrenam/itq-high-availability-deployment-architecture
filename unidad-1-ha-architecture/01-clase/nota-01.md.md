# Alta Disponibilidad y Confiabilidad de Sistemas

En alta disponibilidad y Confiabilidad de Sistemas (SRE/DevOps), mencionar **"3 nueves"** (o **99.9%**) se refiere al **porcentaje de disponibilidad** (_uptime_) garantizado o esperado de un sistema o servicio a lo largo de un año.

El porcentaje indica cuánto tiempo se garantiza que el servicio estará totalmente operativo, lo que a su vez fija el **margen de error aceptable** (_error budget_ o tiempo máximo de caída permitido).

### Tiempo fuera de servicio permitido para "3 nueves" (99.9%)

Si un sistema ofrece un **99.9% de disponibilidad**, el **0.1% restante** representa el tiempo de interrupción máximo tolerable:

|**Período**|**Tiempo máximo de caída (Downtime)**|
|---|---|
|**Diario**|1 minuto y 26 segundos|
|**Mensual**|43 minutos y 49 segundos|
|**Anual**|**8 horas, 45 minutos y 57 segundos**|

### Comparativa: La escala de los "Nueves"

Para ponerlo en contexto frente a otros niveles de disponibilidad comunes en acuerdos de nivel de servicio (SLA):

|**Expresión**|**Porcentaje**|**Downtime Máximo al Año**|**Contexto Típico**|
|---|---|---|---|
|**2 nueves**|99%|3.65 días|Servicios internos no críticos, entornos de desarrollo/pruebas.|
|**3 nueves**|**99.9%**|**8.76 horas**|Estándar para la mayoría de aplicaciones web de producción y SaaS comerciales.|
|**4 nueves**|99.99%|52.56 minutos|Infraestructura en la nube (ej. bases de datos administradas, gateways de API).|
|**5 nueves**|99.999%|5.26 minutos|Sistemas críticos de alta disponibilidad (telecomunicaciones, servicios bancarios centrales, emergencias).|

### Lo que implica pasar a 3 nueves

Subir de 2 nueves a 3 nueves implica cambios arquitectónicos importantes:

- **Eliminación de puntos únicos de falla (SPOF):** Requiere redundancia activa/pasiva o clústeres multi-nodo.
    
- **Failover automático:** La detección de fallas y la conmutación al nodo de respaldo debe ocurrir en segundos o pocos minutos sin intervención humana.
    
- **Mantenimiento sin interrupción (_Zero-downtime deployments_):** Despliegues tipo _Rolling updates_ o _Blue-Green_ para no pausar el servicio durante actualizaciones.

---

## ¿Cómo  medir?

Para una arquitectura de microservicios REST (por ejemplo, un servicio de órdenes/pagos `order-service`), así es como se definen y calculan en la práctica cada una de estas métricas:

### 1. SLI (Service Level Indicator)

Es el porcentaje real de peticiones HTTP exitosas que responde el microservicio en un periodo determinado.

- **Definición:** Medimos peticiones exitosas (código HTTP `< 500`) frente al total de solicitudes recibidas por la API REST.
    
- **Fórmula / Métricas Prometheus:**
    
    $$\text{SLI} = \left( \frac{\text{Respuestas HTTP } 2xx \text{ y } 4xx}{\text{Total de peticiones HTTP}} \right) \times 100$$
    
- **Valor real medido:** En los últimos 30 días, `order-service` atendió $1,000,000$ de peticiones, de las cuales $998,500$ no devolvieron errores $5xx$.
    
    $$\text{SLI} = \left( \frac{998,500}{1,000,000} \right) \times 100 = \mathbf{99.85\%}$$
    

### 2. SLO (Service Level Objective)

Es la meta interna de rendimiento que el equipo de ingeniería establece para ese microservicio REST.

- **Definición:** Mantener la tasa de éxito de la API por encima de un umbral específico en una ventana móvil de 30 días.
    
- **Ejemplo de objetivo:** "El **99.5%** de las peticiones REST al `order-service` deben responder con status $< 500$ y con una latencia $< 200\text{ ms}$ durante 30 días".
    
- **Estado:** Como el SLI actual es **99.85%**, el microservicio **está cumpliendo el SLO** y tiene un _Error Budget_ a favor.
    

### 3. SLA (Service Level Agreement)

Es la garantía legal/comercial ofrecida a los clientes que consumen la API, fijada por debajo del SLO para evitar penalizaciones.

- **Ejemplo contractual:** Garantizar por contrato un **99.0%** de disponibilidad mensual en la API REST.
    
- **Penalización:** Si la disponibilidad cae del $99.0\%$ (más de 7.3 horas de caída en el mes), se acredita un $10\%$ de reembolso a los clientes en su factura de uso de la API.
    

### 4. MTTF (Mean Time To Failure)

Aplica a los componentes físicos o de infraestructura subyacente que no se reparan cuando fallan (ej. los discos NVMe/SSD de las instancias donde corre el clúster o la base de datos).

- **Escenario:** Tienes un pool de 20 instancias con almacenamiento NVMe dedicado corriendo pods de la API. En 3 años, 4 discos fallaron por desgaste de celdas flash acumulando $70,000$ horas totales de uso.
    
- **Cálculo:**
    
    $$\text{MTTF} = \frac{70,000 \text{ horas operativas}}{4 \text{ discos fallados}} = \mathbf{17,500 \text{ horas/disco}}$$
    

### 5. MTTR (Mean Time To Repair)

El tiempo promedio que le toma al equipo (o a la automatización) resolver una caída o degradación del microservicio REST.

- **Escenario:** En un trimestre el `order-service` tuvo 3 incidentes en producción:
    
    1. _Un pod entró en CrashLoopBackOff:_ resuelto mediante _self-healing_ de Kubernetes en 2 minutos.
        
    2. _Fuga de memoria:_ detectada y corregida haciendo un _rollback_ en 15 minutos.
        
    3. _Saturación de conexiones a la base de datos:_ resuelta ajustando el pool de conexiones en 13 minutos.
        
- **Cálculo:**
    
    $$\text{MTTR} = \frac{2 + 15 + 13 \text{ minutos}}{3 \text{ incidentes}} = \mathbf{10 \text{ minutos}}$$
    

### 6. MTBF (Mean Time Between Failures)

El tiempo promedio en que el microservicio opera de forma completamente estable entre el fin de un incidente y el inicio del siguiente.

- **Escenario:** El microservicio estuvo activo durante un periodo de 90 días ($2,160$ horas) y experimentó los 3 incidentes mencionados arriba (que sumaron 30 minutos de tiempo fuera de servicio / MTTR).
    
- **Cálculo:**
    
    $$\text{Tiempo total de uptime} = 2,160 \text{ horas} - 0.5 \text{ horas} = 2,159.5 \text{ horas}$$
    
    $$\text{MTBF} = \frac{2,159.5 \text{ horas}}{3 \text{ fallas}} = \mathbf{719.83 \text{ horas (aprox. 30 días de estabilidad continua entre fallas)}}$$