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