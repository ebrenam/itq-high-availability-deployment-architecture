# 🔒 Unidad 3: Redes de servicio, balanceo y seguridad

## Objetivos de aprendizaje

- Configurar mecanismos de acceso externo y balanceo de carga para microservicios desplegados en Kubernetes.

- Implementar NetworkPolicies para controlar el tráfico entre Pods cuando el CNI del clúster las soporte.

- Aplicar controles de autorización, admisión y seguridad de Pods.

## Estructura de la Unidad

```text
unidad-3-networks/
├── README.md                        # Este archivo
│
├── 01-clase/                        # TEORÍA — Conceptos y principios
│   ├── clase-3-1.md                 # Balanceo, Services, Ingress y Gateway API
│   ├── clase-3-2.md                 # Redes del clúster, NetworkPolicies, aislamiento
│   ├── clase-3-3.md                 # Seguridad: RBAC, SecurityContext, Pod Security Admission
│
├── 02-laboratorio/                  # PRÁCTICA — Implementación hands-on
│   ├── laboratorio-clase-3-1.md     # Lab 3.1: Gateway API, Envoy Gateway y TLS
│   ├── laboratorio-clase-3-2.md     # Lab 3.2: NetworkPolicies
│   ├── laboratorio-clase-3-3.md     # Lab 3.3: RBAC, PSA y SecurityContext
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

**Punto de partida:** El proyecto base contiene `catalog-service` e `inventory-service` heredados de U2. El Laboratorio 3.1 crea un `payment-service` NUEVO (v1.0.0) que hace **llamadas HTTP reales** a los servicios heredados, demostrando **continuidad entre unidades**. payment-service orquesta: validación de producto (catalog-service) + reserva de inventario (inventory-service) + procesamiento de pago simulado.

## Contenido de clases

### **3.1 Balanceo de carga y acceso externo**
- Tipos de exposición de servicios: ClusterIP, NodePort, LoadBalancer, ExternalName
- Arquitectura de Services como balanceadores L4
- Ingress y Gateway API para enrutamiento L7 (HTTP/HTTPS)
- Gestión de certificados TLS/SSL
- **Laboratorio:** Crear payment-service v1.0.0 (orquestador que llama a catalog + inventory de U2); exponerlo con Gateway API + TLS; validar comunicación inter-servicios

### **3.2 Redes del clúster y políticas de comunicación**
- Fundamentos de la red interna de Kubernetes (CNI y modelos de red)
- Control del tráfico entre pods y namespaces
- NetworkPolicies: sintaxis, selectores, reglas Ingress/Egress
- Validación de aislamiento y comunicación permitida
- **Laboratorio:** Reutilizar payment-service de 3.1; implementar NetworkPolicies para aislar servicios (Default Deny a payment-service, permitir Ingress desde Gateway, permitir Egress inter-servicios)

### **3.3 Seguridad en el despliegue y acceso**
- RBAC (Role-Based Access Control): Roles, RoleBindings, ServiceAccounts
- SecurityContext: usuarios no-root, capacidades, privilegios
- Pod Security Standards (Privileged, Baseline, Restricted) y Pod Security Admission
- Principios de mínimo privilegio
- **Laboratorio:** Reutilizar payment-service + NetworkPolicy de 3.1+3.2; aplicar RBAC (ServiceAccount), SecurityContext (runAsNonRoot, readOnlyFilesystem) y PSA (enforce=restricted)

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
| Usarás Deployments, Services, HPA, ConfigMaps | Usarás Gateway API, NetworkPolicy, RBAC y Pod Security Admission | Usarás GitOps, pipelines, ArgoCD |

---

## Punto de partida recomendado

La unidad parte de `02-laboratorio/proyecto-base-unidad-03/`, que contiene `catalog-service` e `inventory-service`, heredados de la Unidad 2. El Laboratorio 3.1 crea un `payment-service` NUEVO v1.0.0 que hace **llamadas HTTP reales** a los servicios heredados, demostrando continuidad y arquitectura de microservicios. Los Laboratorios 3.2 y 3.3 reutilizan este payment-service, agregando capas de seguridad (NetworkPolicy, RBAC, PSA).

---

## Cómo usar esta unidad

### Flujo recomendado

1. **Prerequisito:** Completar [Unidad 2: Kubernetes — Fundamentos y despliegue](../unidad-2-kubernetes/README.md)
2. **Punto de partida:** Usar `02-laboratorio/proyecto-base-unidad-03/`. El Laboratorio 3.1 crea el servicio de demostración; los servicios `catalog-service` e `inventory-service` son extensiones opcionales.
3. **Secuencia del laboratorio:**
   - Laboratorio 3.1: Crear `payment-service` y exponerlo con **Gateway API + TLS**
   - Laboratorio 3.2: Aplicar **NetworkPolicies** para aislar tráfico (si el CNI las implementa)
   - Laboratorio 3.3: Configurar **RBAC + Pod Security Admission + SecurityContext**

### Información rápida

- **Duración estimada:** 6-8 horas (3 clases y 3 laboratorios; ajustable según experiencia y entorno)
- **Tecnología:** Kubernetes (Minikube/Kind), kubectl, Gateway API, Envoy Gateway, Helm, OpenSSL y curl
- **Nivel de dificultad:** Avanzado (requiere completar U2)
- **Resultado esperado:** Endpoint de demostración expuesto por HTTPS con Gateway API y un Pod endurecido; NetworkPolicy se valida si el CNI la implementa

---

## Competencias ganadas

**Específicas:**
- Configurar Services y entrada HTTP con Gateway API; comprender el modelo Ingress
- Implementar políticas de red (NetworkPolicies)
- Aplicar RBAC, Pod Security Admission y SecurityContext

**Genéricas:**
- Administración segura de infraestructura
- Diseño de arquitecturas de red defensivas
- Aplicación de principios de mínimo privilegio

## Bibliografía

- Kubernetes Authors. _Services, Load Balancing, and Networking_. <https://kubernetes.io/docs/concepts/services-networking/>

- Kubernetes Authors. _Network Policies_. <https://kubernetes.io/docs/concepts/services-networking/network-policies/>

- Kubernetes Authors. _Ingress_. La API está estable pero congelada; Kubernetes recomienda Gateway API para desarrollos nuevos. <https://kubernetes.io/docs/concepts/services-networking/ingress/>

- Kubernetes SIG Network. _Gateway API: Getting Started_. <https://gateway-api.sigs.k8s.io/guides/getting-started/introduction/>

- Envoy Gateway. _Quickstart_. <https://gateway.envoyproxy.io/docs/tasks/quickstart/>

- Envoy Gateway. _Compatibility Matrix_. <https://gateway.envoyproxy.io/news/releases/matrix/>

- Kubernetes Authors. _Using RBAC Authorization_. <https://kubernetes.io/docs/reference/access-authn-authz/rbac/>

- Kubernetes Authors. _Pod Security Standards_. <https://kubernetes.io/docs/concepts/security/pod-security-standards/>

- Kubernetes Authors. _Pod Security Admission_. <https://kubernetes.io/docs/concepts/security/pod-security-admission/>

- Kubernetes Authors. _Service Accounts_. <https://kubernetes.io/docs/concepts/security/service-accounts/>

- Kubernetes Authors. _Good practices for Kubernetes Secrets_. <https://kubernetes.io/docs/concepts/security/secrets-good-practices/>

- Kubernetes Authors. _RBAC good practices_. <https://kubernetes.io/docs/concepts/security/rbac-good-practices/>

- Kubernetes SIG Network. _Ingress NGINX Retirement_. <https://kubernetes.io/blog/2025/11/11/ingress-nginx-retirement/>

- National Institute of Standards and Technology. (2020). _Zero Trust Architecture (SP 800-207)_. <https://csrc.nist.gov/pubs/sp/800/207/final>

---

## Conexión con la asignatura y el proyecto integrador

Esta unidad fortalece la arquitectura desplegada en Unidad 2 al definir cómo entra el tráfico al sistema (Gateway API y el modelo Ingress), cómo se controla la comunicación interna (NetworkPolicies, si el CNI las implementa) y cómo se aplican controles de autorización y seguridad de Pods (RBAC, Pod Security Admission y SecurityContext).

El estudiante cierra el ciclo de seguridad multicapa: desde patrones de resiliencia en código (U1) → orquestación en infraestructura (U2) → **exposición y aseguramiento de servicios (U3)** → automatización completa (U4).

---

## Próxima unidad

Después de completar esta unidad, continúa con [Unidad 4: CI/CD y Automatización](../unidad-4-ci-cd/README.md), donde automatizarás el flujo completo de build, test y despliegue usando GitOps y ArgoCD.
