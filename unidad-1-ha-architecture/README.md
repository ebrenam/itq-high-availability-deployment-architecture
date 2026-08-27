# Unidad 1: Arquitecturas de alta disponibilidad y escalabilidad

## Estructura de la Unidad

```text
01-clase/                     # Clases teóricas
├── clase-1-1.md              # Fundamentos de disponibilidad y confiabilidad
├── clase-1-2.md              # Patrones de diseño para resiliencia
└── clase-1-3.md              # Despliegue en la nube y zonas de disponibilidad
   
02-laboratorio/               # Laboratorio con proyecto funcional
├── laboratorio-1.md          # Especificación del laboratorio integrador
├── laboratorio-clase-1-1.md  # Línea base de disponibilidad
├── laboratorio-clase-1-2.md  # Patrones de resiliencia
├── laboratorio-clase-1-3.md  # Despliegue y autocuración
└── proyecto-base/            # Código base (catalog-service)
    ├── desplegar.sh
    ├── docker-compose.yml
    ├── validar.sh
    ├── catalog-service/
    └── ...
```

## Objetivos de aprendizaje

- Identificar los factores que afectan la disponibilidad y la confiabilidad en sistemas distribuidos.

- Diseñar sistemas replicados, balanceados y distribuidos con base en principios de escalabilidad y tolerancia a fallos.

- Reconocer patrones de resiliencia a nivel de infraestructura y su aplicación en entornos cloud.

## Estructura del contenido

### 1.1 Fundamentos de Disponibilidad y Confiabilidad

- Conceptos de disponibilidad, confiabilidad, redundancia y tolerancia a fallos.

- Factores que impactan la continuidad operativa en sistemas distribuidos.

- Relación entre arquitectura, riesgo operativo y niveles de servicio.

### 1.2 Patrones de Diseño para la Resiliencia y la Distribución

- Replicación, balanceo de carga y desacoplamiento de componentes.

- Estrategias para reducir puntos únicos de falla.

- Principios de distribución para soportar crecimiento y recuperación ante incidentes.

### 1.3 Despliegue en la Nube y Zonas de Disponibilidad

- Fundamentos de despliegue distribuido en infraestructura cloud.

- Uso de regiones y zonas de disponibilidad para mejorar resiliencia.

- Consideraciones de diseño para alta disponibilidad en proveedores como AWS, GCP y Azure.

## Competencias

**Específica(s):**

- Identificar factores que afectan disponibilidad.

- Diseñar sistemas replicados, balanceados y distribuidos.

- Conocer patrones de resiliencia a nivel infraestructura.

**Competencias genéricas:**

- Planea y administra el tiempo.

- Formula las especificaciones de un proyecto, considerando restricciones tanto técnicas como económicas y sociales.

- Capacidad de organización.

- Compara diferentes alternativas de solución.

- Selecciona la solución más adecuada, satisfaciendo los requerimientos.

- Capacidad crítica y autocrítica.

- Trabajo en equipo.

- Habilidades interpersonales.

- Capacidad de generar nuevas ideas (creatividad).

- Habilidades de investigación.

- Capacidad de aprender.

## Actividades de aprendizaje

- Elaboración de mapa mental de patrones de alta disponibilidad.

- Análisis de arquitectura real (AWS, GCP, Azure).

- Simulación de fallos y propuesta de mitigación.

## Punto de partida recomendado

La unidad debe iniciar con `u1-starter`: una base mínima funcional de la plataforma e-commerce con el esqueleto del sistema y un primer servicio operativo (`catalog-service`). Ver [02-laboratorio/proyecto-base](02-laboratorio/proyecto-base) y [02-laboratorio/laboratorio-1.md](02-laboratorio/laboratorio-1.md). El resultado final de esta unidad se convierte en el starter de la Unidad 2.

**Flujo pedagógico:**
1. **Semanas 1-2:** Clases teóricas (1.1, 1.2, 1.3) establecen conceptos
2. **Después de la clase 1.1:** [Laboratorio parcial 1.1](02-laboratorio/laboratorio-clase-1-1.md) establece la línea base
3. **Después de la clase 1.2:** [Laboratorio parcial 1.2](02-laboratorio/laboratorio-clase-1-2.md) agrega resiliencia
4. **Después de la clase 1.3:** [Laboratorio parcial 1.3](02-laboratorio/laboratorio-clase-1-3.md) agrega despliegue y autocuración
5. **Cierre:** [Laboratorio integrador](02-laboratorio/laboratorio-1.md) reúne las evidencias

## Bibliografía

- Beyer, B., Jones, C., Petoff, J., & Murphy, N. R. (Eds.). (2016). _Site Reliability Engineering: How Google Runs Production Systems_ (1st ed.). O'Reilly Media. <https://sre.google/sre-book/>

- Beyer, B., Murphy, N. R., Rensin, D. K., Kawahara, K., & Thorne, S. (Eds.). (2018). _The Site Reliability Workbook_. O'Reilly Media. <https://sre.google/workbook/table-of-contents/>

- Fowler, M. (2014, junio 25). _Microservices_. MartinFowler.com. <https://martinfowler.com/articles/microservices.html>

- Heroku. (2012). _The Twelve-Factor App_. <https://12factor.net/>

## Conexión con la asignatura y el proyecto integrador

Esta unidad establece la base conceptual para diseñar una plataforma de microservicios con alta disponibilidad. Proporciona los criterios arquitectónicos que después se materializan en Kubernetes, redes de servicio, automatización de despliegues y observabilidad avanzada.
