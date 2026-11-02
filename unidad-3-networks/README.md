# 🔒 Unidad 3: Redes de servicio, balanceo y seguridad

## Objetivos de aprendizaje

- Configurar mecanismos de acceso externo y balanceo de carga para microservicios desplegados en Kubernetes.

- Implementar políticas de red para controlar la comunicación entre servicios dentro del clúster.

- Aplicar controles de seguridad en el despliegue y la exposición de servicios.

## Estructura de la Unidad

```text
unidad-3-networks/
├── README.md                        # Este archivo
│
├── 01-clase/                        # TEORÍA — Conceptos y principios
│   ├── clase-3-1.md                 # Balanceo de carga, Services, Ingress, LoadBalancers
│   ├── clase-3-2.md                 # Redes del clúster, NetworkPolicies, aislamiento
│   ├── clase-3-3.md                 # Seguridad: RBAC, SecurityContext, Pod Security Standards
│
├── 02-laboratorio/                  # PRÁCTICA — Implementación hands-on
│   ├── laboratorio-clase-3-1.md     # Lab 3.1: Ingress y TLS
│   ├── laboratorio-clase-3-2.md     # Lab 3.2: NetworkPolicies
│   ├── laboratorio-clase-3-3.md     # Lab 3.3: RBAC y SecurityContext
│   ├── images/                      # Screenshots y diagramas de laboratorios
│   │
│   └── proyecto-base-unidad-03/     # Servicios heredados y punto de partida
│       ├── catalog-service/         # Servicio de catálogo (Quarkus, heredado de U2)
│       │   ├── src/
│       │   ├── k8s/
│       │   ├── pom.xml
│       │   └── Dockerfile
│       └── inventory-service/       # Servicio de inventario (Quarkus, heredado de U2)
│           ├── src/
│           ├── k8s/
│           ├── pom.xml
│           └── Dockerfile
```

**Nota sobre el punto de partida:** El proyecto base contiene `catalog-service` e `inventory-service`, pero no incluye `payment-service`. Sin embargo, los laboratorios 3.1–3.3 lo asumen como disponible. Hace falta agregarlo al proyecto base o actualizar las instrucciones de los laboratorios antes de ejecutar esa secuencia.

## Contenido de clases

### **3.1 Balanceo de carga y acceso externo**
- Tipos de exposición de servicios: ClusterIP, NodePort, LoadBalancer, ExternalName
- Arquitectura de Services como balanceadores L4
- Ingress Controllers y enrutamiento L7 (HTTP/HTTPS)
- Gestión de certificados TLS/SSL
- **Laboratorio:** Exponer payment-service con Ingress y TLS

### **3.2 Redes del clúster y políticas de comunicación**
- Fundamentos de la red interna de Kubernetes (CNI, red overlay)
- Control del tráfico entre pods y namespaces
- NetworkPolicies: sintaxis, selectores, reglas Ingress/Egress
- Validación de aislamiento y comunicación permitida
- **Laboratorio:** Implementar NetworkPolicies para aislar servicios

### **3.3 Seguridad en el despliegue y acceso**
- RBAC (Role-Based Access Control): Roles, RoleBindings, ServiceAccounts
- SecurityContext: usuarios no-root, capacidades, privilegios
- Pod Security Standards (Restricted, Baseline, Unrestricted)
- Principios de mínimo privilegio
- **Laboratorio:** Aplicar RBAC y SecurityContext restrictivos

---

## Relación con Unidades Anteriores

Esta unidad **asume que completaste Unidad 2 y entiendes:**

- Cómo crear Deployments y Servicios en Kubernetes
- Conceptos de health probes, rolling updates y autocuración
- Cómo externalizar configuración con ConfigMaps y Secrets
- Fundamentos de escalamiento automático (HPA)
- Cómo desplegar múltiples microservicios en un clúster

Si necesitas refrescar esos conceptos, revisa [Unidad 2: Kubernetes — Fundamentos y despliegue](../unidad-2-kubernetes/README.md).

## Relación con Próximas Unidades

| Unidad Anterior | Esta Unidad | Unidad Siguiente |
|---|---|---|
| **U2: Orquestación en Kubernetes** | **U3: Redes y Seguridad** | **U4: CI/CD y Automatización** |
| Desplegarás microservicios básicos en K8s | Expondrás y asegurarás acceso a servicios | Automatizarás build, test y despliegue |
| Usarás Deployments, Services, HPA, ConfigMaps | Usarás Ingress, NetworkPolicy, RBAC, SecurityContext | Usarás GitOps, pipelines, ArgoCD |
| ~95% disponibilidad en clúster local | ~95% + políticas de red y RBAC | ~95% + automatización y observabilidad |

---

## Punto de partida recomendado

La unidad parte de `02-laboratorio/proyecto-base-unidad-03/`, que contiene `catalog-service` e `inventory-service`, heredados de la Unidad 2. Los laboratorios también requieren `payment-service`, pero ese servicio no está actualmente en el proyecto base; resuelve esta diferencia antes de seguir la secuencia práctica.

---

## Cómo usar esta unidad

### Flujo recomendado

1. **Prerequisito:** Completar [Unidad 2: Kubernetes — Fundamentos y despliegue](../unidad-2-kubernetes/README.md)
2. **Punto de partida:** Usar `02-laboratorio/proyecto-base-unidad-03/` y verificar que estén disponibles los tres servicios requeridos. Actualmente falta `payment-service` en el proyecto base.
3. **Secuencia del laboratorio:**
   - Laboratorio 3.1: Implementar **Ingress + TLS** para exponer servicios
   - Laboratorio 3.2: Aplicar **NetworkPolicies** para aislar tráfico
   - Laboratorio 3.3: Configurar **RBAC + SecurityContext** para endurecimiento

### Información rápida

- **Duración estimada:** 6-8 horas (3 clases de 1-2 horas + 1 laboratorio integrador de 3-4 horas)
- **Tecnología:** Kubernetes (Minikube/Kind), kubectl, NGINX Ingress Controller, OpenSSL
- **Nivel de dificultad:** Avanzado (requiere completar U2)
- **Resultado esperado:** Plataforma e-commerce con 3 microservicios expuestos de forma segura (Ingress + NetworkPolicy + RBAC), una vez disponible `payment-service`
- **Componente requerido:** `payment-service`; los laboratorios lo asumen, pero no está incluido actualmente en el proyecto base

---

## Competencias ganadas

**Específicas:**
- Configurar Ingress Controllers y Load Balancers
- Implementar políticas de red (NetworkPolicies)
- Aplicar RBAC y SecurityContext

**Genéricas:**
- Administración segura de infraestructura
- Diseño de arquitecturas de red defensivas
- Aplicación de principios de mínimo privilegio

## Bibliografía

- Cloud Native Computing Foundation (CNCF). (2024). _Concepts: Services, Load Balancing, and Networking_. Kubernetes Documentation. <https://kubernetes.io/docs/concepts/services-networking/>

- Cloud Native Computing Foundation (CNCF). (2024). _Network Policies_. Kubernetes Documentation. <https://kubernetes.io/docs/concepts/services-networking/network-policies/>

- Cloud Native Computing Foundation (CNCF). (2024). _Ingress_. Kubernetes Documentation. <https://kubernetes.io/docs/concepts/services-networking/ingress/>

- Cloud Native Computing Foundation (CNCF). (2024). _Using RBAC Authorization_. Kubernetes Documentation. <https://kubernetes.io/docs/reference/access-authn-authz/rbac/>

- Cloud Native Computing Foundation (CNCF). (2024). _Pod Security Standards_. Kubernetes Documentation. <https://kubernetes.io/docs/concepts/security/pod-security-standards/>

- Cloud Native Computing Foundation (CNCF). (2024). _Security_. Kubernetes Documentation. <https://kubernetes.io/docs/concepts/security/>

- Cloud Native Computing Foundation (CNCF). (2024). _Istio Documentation: Security_. <https://istio.io/latest/docs/concepts/security/>

- Hightower, K., Burns, B., & Beda, J. (2017). _Kubernetes Up and Running: Dive Into the Future of Infrastructure_ (2nd ed.). O'Reilly Media. ISBN 978-1492046523. (Capítulos 7-8: Services y Ingress)

- Müller, J., & Gerschpacher, T. (2022). _Kubernetes Best Practices: Blueprints for Building Successful Applications on Kubernetes_ (2nd ed.). O'Reilly Media. (Capítulos de seguridad y networking)

- OWASP. (2024). _Kubernetes Security_. <https://owasp.org/www-project-kubernetes-top-ten/>

---

## Conexión con la asignatura y el proyecto integrador

Esta unidad fortalece la arquitectura desplegada en Unidad 2 al definir cómo entra el tráfico al sistema (Ingress), cómo se controla la comunicación interna (NetworkPolicies) y qué mecanismos de seguridad se requieren para operar microservicios expuestos en un entorno productivo (RBAC, SecurityContext, Pod Security Standards). 

El estudiante cierra el ciclo de seguridad multicapa: desde patrones de resiliencia en código (U1) → orquestación en infraestructura (U2) → **exposición y aseguramiento de servicios (U3)** → automatización completa (U4).

---

## Próxima unidad

Después de completar esta unidad, continúa con [Unidad 4: CI/CD y Automatización](../unidad-4-ci-cd/README.md), donde automatizarás el flujo completo de build, test y despliegue usando GitOps y ArgoCD.
