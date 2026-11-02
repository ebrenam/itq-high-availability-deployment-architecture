# Unidad 2: Kubernetes — Fundamentos y despliegue de microservicios

## Objetivos de aprendizaje

- Comprender la arquitectura de Kubernetes y sus componentes clave para la operación de microservicios.

- Crear despliegues, servicios y objetos de configuración para administrar aplicaciones distribuidas con alta disponibilidad.

- Implementar escalamiento automático y mecanismos de actualización y recuperación sobre un clúster.

## Estructura de la Unidad

```text
unidad-2-kubernetes/
├── README.md                        # Este archivo
│
├── 01-clase/                        # TEORÍA — Conceptos y principios
│   ├── clase-2-1.md                 # Arquitectura K8s, control plane, worker nodes
│   ├── clase-2-2.md                 # Deployments, ReplicaSets, Rolling Updates
│   ├── clase-2-3.md                 # ConfigMaps, Secrets, HPA (Horizontal Pod Autoscaler)
│   ├── anexo-versionamiento.md      # Estrategia de versiones para microservicios
│   └── images/                      # Diagramas conceptuales
│
├── 02-laboratorio/                  # PRÁCTICA — Implementación hands-on
│   ├── laboratorio-clase-2-1.md     # Lab 2.1: Arquitectura y Componentes Clave
│   ├── laboratorio-clase-2-2.md     # Lab 2.2: Deployments, RollingUpdate, Health Probes
│   ├── laboratorio-clase-2-3.md     # Lab 2.3: ConfigMaps, Secrets, HPA
│   ├── demo-deployment.yaml         # Manifiesto de demostración
│   ├── images/                      # Screenshots y diagramas de laboratorios
│   │
│   └── proyecto-base-unidad-02/     # CÓDIGO FUNCIONAL — Microservicios en K8s
│       └── catalog-service/         # Servicio de catálogo (Quarkus)
│           ├── README.md            # Setup rápido + referencias a laboratorios
│           ├── src/                 # Código fuente y configuración de Quarkus
│           ├── k8s/                 # Manifiestos del servicio de catálogo
│           ├── pom.xml              # Dependencias y configuración de Maven
│           └── Dockerfile           # Construcción de la imagen del servicio
```

El proyecto base contiene `catalog-service`. Durante el Laboratorio 2.2 crearás `inventory-service` dentro de `proyecto-base-unidad-02/`; el Laboratorio 2.3 continúa trabajando con ambos servicios.

## Relación con Unidades Anteriores

Esta unidad **asume que completaste Unidad 1 y entiendes:**

- Conceptos de disponibilidad, confiabilidad y SLO (Service Level Objectives)
- Patrones de resiliencia a nivel de código (Timeout, Retry, Circuit Breaker, Fallback)
- Cómo desplegar una aplicación microservicios en tu máquina local
- Bases de infraestructura multi-AZ y autocuración (_self-healing_)

Si necesitas refrescar esos conceptos, revisa [Unidad 1: Arquitecturas de Alta Disponibilidad](../unidad-1-ha-architecture/README.md).

## Contenido de clases

### **2.1 Arquitectura y componentes clave**
- Componentes del Control Plane: API Server, etcd, Scheduler, Controller Manager
- Componentes de Worker Nodes: kubelet, kube-proxy, container runtime
- Modelo declarativo: Objects y Resources
- Relación entre Pods, Nodos y Servicios
- **Laboratorio:** Inspeccionar componentes en cluster local e implementar manifiestos YAML

### **2.2 Objetos de despliegue para alta disponibilidad**
- ReplicaSets: Garantizar N réplicas idénticas
- Deployments: Abstracción de alto nivel para aplicaciones stateless
- Estrategias de actualización: Recreate vs. RollingUpdate (zero-downtime)
- Probes de salud: StartupProbe, ReadinessProbe, LivenessProbe
- Autocuración (_self-healing_) y tolerancia a fallos
- **Laboratorio:** Desplegar aplicación con RollingUpdate y configurar health probes

### **2.3 Configuración y escalamiento automático**
- ConfigMaps: Gestión de configuración externa desacoplada
- Secrets: Almacenamiento seguro de credenciales
- HPA (Horizontal Pod Autoscaler): Escalamiento automático basado en métricas
- Gestión de recursos: requests y limits
- **Laboratorio:** Externalizar configuración, implementar HPA y validar escalamiento

---

## Relación con Próximas Unidades

| Unidad Anterior | Esta Unidad | Unidad Siguiente |
|---|---|---|
| **U1: Patrones de resiliencia en software** | **U2: Orquestación en Kubernetes** | **U3: Redes y Service Mesh** |
| Entendiste HA a nivel de código (patrones) | Orquestas HA en infraestructura (clúster) | Enrutarás tráfico inteligentemente entre servicios |
| Mediste ~65% disponibilidad sin patrones | Desplegarás en K8s con ~95%+ disponibilidad | Aplicarás políticas de red y observabilidad de tráfico |
| Usaste `@Timeout`, `@Retry`, `@Fallback` | Usarás Deployments, RollingUpdate, HPA | Usarás Ingress, NetworkPolicy, Service Mesh |

## Punto de partida recomendado

La unidad parte de `02-laboratorio/proyecto-base-unidad-02/catalog-service`, el servicio de catálogo heredado de la Unidad 1. Durante el Laboratorio 2.2, crearás `inventory-service` dentro de `proyecto-base-unidad-02/`; en el Laboratorio 2.3 continuarás con ambos servicios.

## Bibliografía

- Cloud Native Computing Foundation (CNCF). (2024). _Kubernetes Documentation: Concepts_. <https://kubernetes.io/docs/concepts/>

- Cloud Native Computing Foundation (CNCF). (2024). _Kubernetes Documentation: Components_. <https://kubernetes.io/docs/concepts/overview/components/>

- Cloud Native Computing Foundation (CNCF). (2024). _Kubernetes Documentation: Deployments_. <https://kubernetes.io/docs/concepts/workloads/controllers/deployment/>

- Cloud Native Computing Foundation (CNCF). (2024). _Kubernetes Documentation: Pods (Ciclo de Vida)_. <https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle/>

- Cloud Native Computing Foundation (CNCF). (2024). _Kubernetes Documentation: Horizontal Pod Autoscaler_. <https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/>

- Cloud Native Computing Foundation (CNCF). (2024). _Kubernetes Documentation: ConfigMaps_. <https://kubernetes.io/docs/concepts/configuration/configmap/>

- Cloud Native Computing Foundation (CNCF). (2024). _Kubernetes Documentation: Secrets_. <https://kubernetes.io/docs/concepts/configuration/secret/>

- Hightower, K., Burns, B., & Beda, J. (2017). _Kubernetes Up and Running: Dive Into the Future of Infrastructure_ (2nd ed.). O'Reilly Media. ISBN 978-1492046523.

- Müller, J., & Gerschpacher, T. (2022). _Kubernetes Best Practices: Blueprints for Building Successful Applications on Kubernetes_ (2nd ed.). O'Reilly Media.

- The Twelve-Factor App. (2024). _III. Store config in the environment_. <https://12factor.net/config>

## Conexión con la asignatura y el proyecto integrador

Esta unidad convierte los principios de disponibilidad aprendidos en Unidad 1 en una operación real sobre Kubernetes. El estudiante despliega microservicios, define su configuración y establece las bases de escalamiento y recuperación automática sobre un clúster.
