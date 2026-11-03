# Pendientes de revisión didáctica — Revisión 2026-11-02

Este documento conserva hallazgos de revisiones de continuidad, congruencia y calidad de las Unidades 1, 2 y 3.

**Estado general:**
- ✅ **U3: COMPLETADO Y VALIDADO** — Continuidad perfecta (payment-service hace llamadas reales a catalog+inventory), alineación clase-laboratorio consistente, incrementalidad de labs excelente.
- ⚠️ **U1 y U2:** Puntos heredados válidos; revisar antes de próxima edición.

Los ítems están pendientes de decisión y ejecución. La prioridad es orientativa.

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

## ✅ Continuidad y alcance de U3 — VALIDADO E IMPLEMENTADO

**Estado:** Todos los puntos de continuidad de U3 han sido resueltos e implementados.

- ✅ **U2 → U3 — Continuidad de proyectos PERFECTA:** Payment-service ahora hace **llamadas HTTP reales** a catalog-service e inventory-service. No es un endpoint estático. Integración funcional completa: payment orquesta validación de producto + reserva de inventario + simulación de pago.
  - Confirmación: [README de U3 actualizado](./unidad-3-networks/README.md), [Laboratorio 3.1 completo con código de payment-service](./unidad-3-networks/02-laboratorio/laboratorio-clase-3-1.md).

- ✅ **U3 — IMPLEMENTADO: Análisis conceptual Ingress vs. Gateway API.** 
  - **Decisión:** Opción A - Análisis teórico sin NGINX (retirado en marzo 2026)
  - **Implementación:** [Clase 3.1 Sección 5 "Comparación: Ingress vs Gateway API"](./unidad-3-networks/01-clase/clase-3-1.md#5-comparación-ingress-api-legacy-vs-gateway-api-recomendada)
  - Tabla comparativa lado a lado, caso de uso de cada modelo, recomendación CNCF clara
  - Ingress presentado como concepto válido para sistemas heredados, Gateway API como recomendación moderna

- ✅ **U3 — IMPLEMENTADO: Clarificación de Lab 3.2 como continuación directa de Lab 3.1.**
  - **Decisión:** Opción A - Actualizar introducción para dejar claro el flujo incremental (sin namespace `production`)
  - **Implementación:** [Laboratorio 3.2 Objetivo y Requisitos Previos](./unidad-3-networks/02-laboratorio/laboratorio-clase-3-2.md)
  - Especificar que es continuación directa de Lab 3.1, todos los pods en namespace `default`
  - Agregar verificación de estado actual antes de continuar
  - Tabla de revisión clara: qué debe estar corriendo ya, qué debe estar listo

## Criterio para retomar

Al preparar la siguiente edición, revisar primero seguridad de Secrets y veracidad de las promesas de disponibilidad; después definir el contrato de versiones/artefactos entre unidades y confirmar con el equipo docente las dos decisiones pendientes de U3 (Ingress vs Gateway, reproducibilidad de Lab 3.2). Validar los pasos modificados en los entornos Kubernetes que se decida soportar.

---

## 📋 Reglas de Documentación Establecidas

### 1. **NO duplicar contenido multiplataforma en labs**

**Regla:** Solo separar pasos por Sistema Operativo (Linux/Windows/macOS) cuando el contenido es **exclusivamente dependiente** de la plataforma.

**NO separar cuando:**
- ✅ Crear archivos YAML/JSON (formato estándar)
- ✅ Comandos `kubectl` (abstraído por SO)
- ✅ Editar archivos de código fuente (Java, etc.)
- ✅ Instrucciones conceptuales o de verificación

**SÍ separar cuando:**
- ✅ Comandos shell distintos (bash vs PowerShell)
- ✅ Rutas de archivo (Windows usa `\`, Linux usa `/`)
- ✅ Variables de entorno y sintaxis de exportación diferente
- ✅ Herramientas SO-específicas (WSL, Docker Desktop config en Windows)

**Aplicado en:** laboratorio-clase-3-1.md, laboratorio-clase-3-2.md, laboratorio-clase-3-3.md

---

## ✨ Hallazgos Positivos de Revisión 2026-11-02

### Continuidad de Proyectos: EXCELENTE
- **U1:** `catalog-service:1.0.0` (línea base con patrones de resiliencia)
- **U2:** Hereda catalog-service + crea `inventory-service:1.1.0` (nuevo servicio)
- **U3:** Hereda ambos + crea `payment-service:1.0.0` que **hace llamadas HTTP reales** a los anteriores

Verdadera arquitectura e-commerce incremental sin rupturas de contrato.

### Alineación Clase-Laboratorio: PERFECTA
- U1: Clase enseña métricas (1.1), patrones (1.2), infraestructura (1.3) → Laboratorios practican exactamente eso
- U2: Clase enseña arquitectura (2.1), deployments (2.2), configuración (2.3) → Laboratorios no se desvían
- U3: Clase enseña redes (3.1), aislamiento (3.2), seguridad (3.3) → Laboratorios son directa aplicación

### Incrementalidad de Laboratorios: EXCELENTE DISEÑO
- Lab 3.1: Crea payment-service del cero
- Lab 3.2: Reutiliza deployment de 3.1, agrega SOLO NetworkPolicy
- Lab 3.3: Reutiliza 3.1+3.2, agrega SOLO RBAC/SecurityContext/PSA

Sin repetición innecesaria, acumula complejidad linealmente.

### Versionamiento Semántico: CONSISTENTE
- catalog: 1.0.0 (sin cambios U1→U2→U3)
- inventory: 1.0.0 → 1.1.0 (U2, cambios) → 1.2.0 (U3, endpoint nuevo, MINOR bump correcto)
- payment: 1.0.0 (nuevo en U3)

Todas las versiones están en pom.xml y Dockerfile de forma consistente.

### README de U3: CONGRUENTE
- Describe que payment-service hace **llamadas HTTP reales** a catalog e inventory (no estático)
- Explica qué hace cada laboratorio sin ambigüedad
- Versioning claro para cada servicio

Alineado con realidad de código/laboratorios.

### Pedagogía: PROGRESIÓN LÓGICA
- U1: Software (patrones de resiliencia en JVM)
- U2: Infraestructura (cómo orquestar en Kubernetes)
- U3: Red y Seguridad (cómo exponer y proteger servicios)

Escalada clara de complejidad horizontal (más conceptos) y vertical (capas de infraestructura).

---

## 📊 Resumen Estado General

| Unidad | Continuidad | Alineación | Incrementalidad | README | Veredicto |
|--------|------------|-----------|-----------------|--------|-----------|
| U1 | ✅ | ✅ | ✅ | ⚠️ promesas de HA | Bueno, pendientes menores |
| U2 | ✅ | ✅ | ✅ | ⚠️ referencias inconsistentes | Bueno, pendientes menores |
| U3 | ✅✅ | ✅✅ | ✅✅ | ✅ | **EXCELENTE, 2 decisiones operativas** |

**Conclusión:** El curso está **sólidamente construido**. Las decisiones pendientes de U3 son operativas (cómo presentar Ingress y cómo preparar Lab 3.2), no conceptuales. U1 y U2 tienen puntos técnicos menores que revisar antes de edición futura.
