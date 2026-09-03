# 🚀 Unidad 1: Arquitecturas de Alta Disponibilidad y Escalabilidad

## Objetivos de aprendizaje

- Identificar los factores que afectan la disponibilidad y la confiabilidad en sistemas distribuidos.

- Diseñar sistemas replicados, balanceados y distribuidos con base en principios de escalabilidad y tolerancia a fallos.

- Reconocer patrones de resiliencia a nivel de infraestructura y su aplicación en entornos cloud.

## Estructura de la Unidad

```text
unidad-1-ha-architecture/
├── glosario.md                      # Diccionario de términos
├── README.md                        # Este archivo
│
├── 01-clase/                        # TEORÍA — Conceptos y principios
│   ├── clase-1-1.md                 # Disponibilidad, confiabilidad, SLI/SLO/SLA
│   ├── clase-1-2.md                 # Patrones: Timeout, Retry, CircuitBreaker, Fallback
│   ├── clase-1-3.md                 # Multi-AZ, Kubernetes, autocuración
│   └── images/                      # Diagramas conceptuales
│
├── 02-laboratorio/                  # PRÁCTICA — Implementación hands-on
│   ├── laboratorio-clase-1-1.md     # Lab 1.1: Medir línea base (~70% disponibilidad)
│   ├── laboratorio-clase-1-2.md     # Lab 1.2: Implementar patrones (~90%+ disponibilidad)
│   ├── laboratorio-clase-1-3.md     # Lab 1.3: Desplegar en Kubernetes (~99%+ disponibilidad)
│   │
│   └── proyecto-base-unidad-01/     # CÓDIGO FUNCIONAL — Catalog Service
│       └── catalog-service/         # Microservicio resiliente
│           ├── README.md            # Setup rápido + referencias a laboratorios
│           ├── src/main/java/.../
│           │   └── CatalogResource.java      # Editarás aquí (Labs 1.1→1.2→1.3)
│           ├── src/main/resources/
│           │   └── application.properties    # Config Quarkus
│           ├── k8s/
│           │   ├── 01-deployment.yaml        # Editarás aquí (Lab 1.3)
│           │   └── 02-service.yaml           # Editarás aquí (Lab 1.3)
│           ├── pom.xml                       # Dependencies (Quarkus 3.38.0)
│           ├── Dockerfile                    # Imagen Docker multi-stage
│           └── target/                       # Build artifacts
```

## Contenido de Clases

### **1.1 Fundamentos de Disponibilidad y Confiabilidad**
- Conceptos: Disponibilidad vs. Confiabilidad
- Métricas: SLI, SLO, SLA, MTTR, MTTF, MTBF
- Puntos únicos de fallo (SPOF)
- Error budgets
- **Laboratorio:** Medir baseline sin patrones

### **1.2 Patrones de Diseño para Resiliencia**
- Timeout: Cancela operaciones lentas
- Retry: Reintenta automáticamente
- Circuit Breaker: Protege contra cascadas
- Fallback: Degradación elegante
- Bulkhead: Aislamiento de recursos
- **Laboratorio:** Implementar 4 patrones en código

### **1.3 Despliegue en Nube Multi-AZ**
- Regiones y Zonas de Disponibilidad
- Single-AZ vs. Multi-AZ
- Kubernetes y orquestación automática
- Health checks (startup, liveness, readiness)
- Topology spread constraints
- Autocuración (_self-healing_)
- **Laboratorio:** Desplegar en Kubernetes con 3 réplicas

---

## Relación con Próximas Unidades

| Unidad Anterior | Esta Unidad | Unidad Siguiente |
|-----------------|-------------|-----------------|
| — | **Unidad 1: HA-Architecture** | Unidad 2: Kubernetes |
| | Construyes una app resiliente con patrones de software | Orquestas a escala: DaemonSets, StatefulSets, Operators |
| | Despliegas en Kubernetes local | Despliegas en clusters multi-nodo, prod-ready |
| | Validas autocuración básica | Validas rolling updates, blue-green deployments |

## Bibliografía

- Beyer, B., Jones, C., Petoff, J., & Murphy, N. R. (Eds.). (2016). _Site Reliability Engineering: How Google Runs Production Systems_ (1st ed.). O'Reilly Media. <https://sre.google/sre-book/>

- Beyer, B., Murphy, N. R., Rensin, D. K., Kawahara, K., & Thorne, S. (Eds.). (2018). _The Site Reliability Workbook_. O'Reilly Media. <https://sre.google/workbook/table-of-contents/>

- Fowler, M. (2014, junio 25). _Microservices_. MartinFowler.com. <https://martinfowler.com/articles/microservices.html>

- Heroku. (2012). _The Twelve-Factor App_. <https://12factor.net/>

## Conexión con la asignatura y el proyecto integrador

Esta unidad establece la base conceptual para diseñar una plataforma de microservicios con alta disponibilidad. Proporciona los criterios arquitectónicos que después se materializan en Kubernetes, redes de servicio, automatización de despliegues y observabilidad avanzada.
