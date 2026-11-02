# Pendientes de revisión didáctica

Este documento conserva hallazgos de la revisión de continuidad, congruencia y calidad de las Unidades 1, 2 y 3. **Las Unidades 1 y 2 ya fueron cursadas por los estudiantes**; estos puntos se registran para que el equipo docente decida si conviene ajustar los materiales antes de una edición futura. No implican cambios retroactivos a las actividades ya realizadas.

Los ítems están pendientes de decisión y ejecución; no se consideran resueltos por estar documentados aquí. La prioridad es orientativa.

## Prioridad alta

- [ ] **U2 — Revisar el ejemplo y las evidencias de Secrets.** Sustituir cualquier valor con apariencia de credencial real por marcadores claramente ficticios. Evitar imprimir el entorno completo o exponer contraseñas/tokens en capturas y entregables; validar presencia/configuración sin mostrar valores.
  - Referencia: [Laboratorio 2.3](./unidad-2-kubernetes/02-laboratorio/laboratorio-clase-2-3.md).

- [ ] **U1 — Alinear las promesas de alta disponibilidad con lo que demuestra el laboratorio.** El README presenta el Laboratorio 1.3 como Multi-AZ y/o de varias réplicas, mientras el manifiesto base despliega una réplica en un clúster local y no define distribución entre zonas. Aclarar que se trata de una base de despliegue local o ampliar el ejercicio en un entorno que permita probar réplicas y topología; no presentar el resultado como HA Multi-AZ sin esa validación.
  - Referencias: [README de U1](./unidad-1-ha-architecture/README.md), [Laboratorio 1.3](./unidad-1-ha-architecture/02-laboratorio/laboratorio-clase-1-3.md), [Deployment del catálogo](./unidad-1-ha-architecture/02-laboratorio/proyecto-base-unidad-01/catalog-service/k8s/01-deployment.yaml).

- [ ] **U1 — Precisar el SLI de disponibilidad.** Separar respuestas exitosas funcionalmente, respuestas degradadas, errores y latencia. Definir explícitamente cuándo una respuesta lenta o con datos de fallback cuenta como buena para el usuario; evitar equiparar automáticamente HTTP 200 con disponibilidad satisfactoria.
  - Referencias: [Laboratorio 1.1](./unidad-1-ha-architecture/02-laboratorio/laboratorio-clase-1-1.md), [Laboratorio 1.2](./unidad-1-ha-architecture/02-laboratorio/laboratorio-clase-1-2.md).

## Prioridad media

- [ ] **U1 — Corregir el modelo de estado en la simulación de fallos.** Revisar la explicación y el uso de `ThreadLocal`: sus valores pertenecen al hilo y no se reinician automáticamente por solicitud. Asegurar inicialización y limpieza fiables del estado usado para demostrar reintentos y fallos, o simplificar la simulación.
  - Referencia: [Laboratorio 1.2](./unidad-1-ha-architecture/02-laboratorio/laboratorio-clase-1-2.md).

- [ ] **U1 — Evitar readiness aleatoria como estado de salud del servicio.** El health check de catálogo puede fallar aleatoriamente, lo que confunde una condición real de disponibilidad con una simulación e interfiere con la selección de endpoints. Hacerlo determinista o explicar y aislar explícitamente el efecto didáctico.
  - Referencias: [ReadinessHealthCheck.java](./unidad-1-ha-architecture/02-laboratorio/proyecto-base-unidad-01/catalog-service/src/main/java/com/ecom/catalog/ReadinessHealthCheck.java), [Deployment del catálogo](./unidad-1-ha-architecture/02-laboratorio/proyecto-base-unidad-01/catalog-service/k8s/01-deployment.yaml).

- [ ] **U1 — Hacer reproducible la verificación de descarga de imagen.** No asumir que borrar una imagen del runtime Docker local elimina la copia usada por Minikube/Kind ni que `IfNotPresent` obliga a descargarla. Verificar tag, estado y eventos; si se quiere enseñar una descarga, usar un tag no almacenado y documentar el runtime y `imagePullPolicy`.
  - Referencia: [Laboratorio 1.3](./unidad-1-ha-architecture/02-laboratorio/laboratorio-clase-1-3.md).

- [ ] **U2 — Matizar el objetivo “cero downtime” y la semántica del rollback.** Presentar `maxUnavailable: 0` como configuración orientada a mantener capacidad durante un rollout, no como garantía absoluta de cero solicitudes fallidas. Explicitar las condiciones necesarias (readiness, capacidad, salud y comportamiento de la aplicación), medir errores durante la actualización y aclarar que el rollback requiere una acción (`kubectl rollout undo`) o automatización externa.
  - Referencias: [Clase 2.2](./unidad-2-kubernetes/01-clase/clase-2-2.md), [Laboratorio 2.2](./unidad-2-kubernetes/02-laboratorio/laboratorio-clase-2-2.md).

- [ ] **U2 — Diferenciar los pasos de verificación por entorno.** El Laboratorio 2.1 declara compatibilidad con Minikube y Kind, pero algunas comprobaciones del plano de control no se comportan igual en ambos; revisar también el uso de `componentstatuses`. Especificar un entorno requerido o dar procedimientos y verificaciones válidos para cada distribución.
  - Referencia: [Laboratorio 2.1](./unidad-2-kubernetes/02-laboratorio/laboratorio-clase-2-1.md).

- [ ] **U2 — Mejorar la explicación de ConfigMap, Secret y transporte.** Evitar describir ConfigMaps como “públicos” por defecto o sugerir que TLS es opcional para proteger el acceso a la API. Distinguir acceso mediante RBAC, TLS en tránsito y cifrado de datos en reposo; un objeto Secret no queda cifrado solo por su tipo.
  - Referencia: [Clase 2.3](./unidad-2-kubernetes/01-clase/clase-2-3.md).

- [ ] **U2 — Corregir referencias inconsistentes a nombres de recursos en los ejemplos.** Alinear el nombre del Deployment usado en las salidas HPA con el manifiesto (`inventory-service`) y corregir el nombre de Pod de catálogo en la evidencia de U2.2.
  - Referencias: [Laboratorio 2.3](./unidad-2-kubernetes/02-laboratorio/laboratorio-clase-2-3.md), [Laboratorio 2.2](./unidad-2-kubernetes/02-laboratorio/laboratorio-clase-2-2.md), [Deployment de catálogo en U2](./unidad-2-kubernetes/02-laboratorio/proyecto-base-unidad-02/catalog-service/k8s/01-deployment.yaml).

- [ ] **U2 → U3 — Definir un baseline reproducible para el traspaso de `inventory-service`.** U2 construye/publica una versión que el cierre del laboratorio identifica como `1.1.0`, mientras el manifiesto de U3 apunta a la imagen `1.0.0` y el código de U3 reporta `v1.1.0`. Precisar si U3 parte de la imagen/código producido por el estudiante o de su propio starter; registrar tag, versión de código, manifiestos y efecto del rollback final de U2.
  - Referencias: [Laboratorio 2.2](./unidad-2-kubernetes/02-laboratorio/laboratorio-clase-2-2.md), [Deployment de inventario en U3](./unidad-3-networks/02-laboratorio/proyecto-base-unidad-03/inventory-service/k8s/deployment-service.yaml), [InventoryResource.java](./unidad-3-networks/02-laboratorio/proyecto-base-unidad-03/inventory-service/src/main/java/com/ecom/inventory/InventoryResource.java).

## Continuidad y alcance de U3

- [ ] **U2 → U3 — Decidir si U3 continúa el sistema integrado o enseña una tecnología de forma aislada.** El Laboratorio 3.1 crea un endpoint estático `payment-service`; los servicios reales `catalog-service` e `inventory-service` no son necesarios para la secuencia base. Alinear el README, los diagramas y los objetivos: declarar el laboratorio como aislado/de demostración o diseñar una integración incremental con los servicios heredados.
  - Referencias: [README de U3](./unidad-3-networks/README.md), [Clase 3.1](./unidad-3-networks/01-clase/clase-3-1.md), [Laboratorio 3.1](./unidad-3-networks/02-laboratorio/laboratorio-clase-3-1.md).

- [ ] **U3 — Alinear la comparación anunciada entre Ingress y Gateway API con la actividad real.** El README promete comparar ambos modelos, pero el Laboratorio 3.1 configura Gateway API. Agregar una actividad de comparación conceptual basada en sus recursos/capacidades o ajustar el objetivo; no reinstalar Ingress NGINX, que fue retirado.
  - Referencias: [README de U3](./unidad-3-networks/README.md), [Laboratorio 3.1](./unidad-3-networks/02-laboratorio/laboratorio-clase-3-1.md).

- [ ] **U3 — Hacer reproducible la extensión opcional interservicios del Laboratorio 3.2.** La sección supone `catalog-service` e `inventory-service` desplegados en `production` y con imágenes disponibles, aunque no provee los pasos para construir/publicar esas imágenes. Agregar instrucciones ejecutables de preparación o mantener la sección explícitamente como ejercicio de diseño de reglas, sin afirmar que los servicios están listos para probarse.
  - Referencias: [Laboratorio 3.2](./unidad-3-networks/02-laboratorio/laboratorio-clase-3-2.md), [Deployment de catálogo](./unidad-3-networks/02-laboratorio/proyecto-base-unidad-03/catalog-service/k8s/01-deployment.yaml), [Deployment de inventario](./unidad-3-networks/02-laboratorio/proyecto-base-unidad-03/inventory-service/k8s/deployment-service.yaml).

## Criterio para retomar

Al preparar la siguiente edición, revisar primero seguridad de Secrets y veracidad de las promesas de disponibilidad; después definir el contrato de versiones/artefactos entre unidades y confirmar con el equipo docente el alcance integrado o aislado de U3. Validar los pasos modificados en los entornos Kubernetes que se decida soportar.
