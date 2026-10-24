# 3.2 Redes del Clúster y Políticas de Comunicación

En la sesión anterior analizamos cómo gestionar el tráfico de entrada mediante _Services_, _Ingress_ y terminación TLS, y ahora en esta sesión llevaremos ese conocimiento a la práctica al explorar _NetworkPolicies_, el CNI y el aislamiento del tráfico interno.

## 1. Explicación conceptual

A diferencia de la infraestructura tradicional donde las máquinas virtuales se aíslan con VLANs o subredes fijas, Kubernetes utiliza un modelo plano de red (_flat network_) gobernado por tres reglas fundamentales:

1. Todo _pod_ obtiene su propia IP en una red _overlay_ accesible por todo el clúster.

2. Todos los _pods_ pueden comunicarse con cualquier otro _pod_ en el clúster **sin necesidad de NAT** (_Network Address Translation_).

3. Todos los nodos pueden comunicarse con todos los _pods_ del clúster sin NAT.

### 1.1 El motor subyacente: Container Network Interface (CNI)

Kubernetes no gestiona las interfaces de red ni las tablas de ruteo directamente; delega esta función a un _plugin_ de **CNI**:

- **Flannel:** Plugin simple de capa 2 (L2) que crea una red _overlay_ con encapsulamiento VXLAN. Es ligero, pero no soporta _NetworkPolicies_.

- **Calico:** Plugin de capa 3 (L3) altamente escalable que utiliza BGP (_Border Gateway Protocol_) para ruteo directo o encapsulamiento IP-in-IP/VXLAN. Implementa reglas de seguridad nativas.

- **Cilium:** Plugin de última generación respaldado por **eBPF** (_Extended Berkeley Packet Filter_). Procesa paquetes directamente en el Kernel de Linux, evitando la sobrecarga de _iptables_ y ofreciendo observabilidad y seguridad en capa 7 (L7).

### 1.2 Seguridad con modelo Zero Trust: NetworkPolicies

Por defecto, la red de Kubernetes es **plana y totalmente abierta**: cualquier _pod_ en cualquier _namespace_ puede hablar con cualquier otro _pod_. Para implementar el principio de mínimo privilegio (_Zero Trust_), declaramos objetos **`NetworkPolicy`**.

Una `NetworkPolicy` actúa como un _firewall_ distribuido basado en etiquetas (_labels_) y _namespaces_:

- **`Ingress`:** Controla qué tráfico entrante se permite hacia los _pods_ seleccionados.

- **`Egress`:** Controla qué tráfico saliente se permite desde los _pods_ seleccionados hacia otros _pods_, rangos CIDR o servicios externos.

### 1.3 Descubrimiento de servicios con CoreDNS

Para evitar acoplarse a IPs dinámicas, el clúster integra **CoreDNS**. Cada vez que creas un `Service`, CoreDNS le asigna un nombre de dominio completamente calificado (_FQDN_):

```text
<nombre-servicio>.<namespace>.svc.cluster.local
```

Si dos microservicios conviven en el mismo _namespace_, basta con invocar `<nombre-servicio>:<puerto>`.

---

## 2. Analogía del mundo real

Imagina un gran edificio corporativo _open space_ sin paredes físicas interiores:

- **Modelo de red plano (IP por pod):** Todos los empleados caminan por el mismo pasillo principal. Cuestión de tiempo para que cualquiera pueda ir al escritorio de quien sea sin restricciones.

- **El CNI (El sistema de ventilación y accesos):**

    - _Flannel_ es poner tuberías de aire estándar. Cumple con llevar oxígeno pero no tiene puertas de seguridad.

    - _Calico_ es poner torniquetes con tarjetas magnéticas en cada pasillo.

    - _Cilium_ es colocar escáneres de reconocimiento facial con rayos X (eBPF) instalados directamente en las puertas; detectan si alguien lleva algo no autorizado sin detener el flujo de personas.

- **NetworkPolicies (Tarjetas de acceso VIP):** Por defecto, el becario de marketing puede entrar al cuarto del servidor de la nómina de la empresa. Al aplicar una `NetworkPolicy`, colocas un lector biométrico: solo los empleados etiquetados como `role: finance` pueden traspasar la puerta del cuarto `namespace: accounting`.

- **CoreDNS (El directorio telefónico interno):** Nadie en la empresa se memoriza las extensiones de 10 dígitos de sus compañeros. Abres la libreta y buscas "Servicio de Inventario", e internamente el directorio te enlaza con la extensión actual de la persona, cambie de escritorio o no.

---

## 3. Modelos de Aislamiento: Default Deny vs Allow-List

La práctica profesional de seguridad en Kubernetes sigue el modelo **Allow-List** (lista blanca):

| Modelo | Estrategia | Seguridad | Complejidad |
|--------|-----------|----------|-------------|
| **Default Allow** | Bloquea solo lo conocido como peligroso | ⚠️ Baja (hay muchas cosas desconocidas) | Baja |
| **Default Deny** | Bloquea TODO, permite solo lo explícito | ✅ Alta | Media |
| **Zero Trust** | Default Deny + autenticación/autorización mutua | ✅✅ Máxima | Alta |

```
┌─────────────────────────────────────────────────────────┐
│ Kubernetes Network (Default: Todos pueden hablar)       │
├─────────────────────────────────────────────────────────┤
│                                                           │
│  ┌──────────────────┐           ┌──────────────────┐   │
│  │ web-pod          │   ═════→  │ db-pod           │   │ ✅ Permitido
│  │ (label: frontend)│           │ (label: backend) │   │
│  └──────────────────┘           └──────────────────┘   │
│                                                           │
│  ┌──────────────────┐           ┌──────────────────┐   │
│  │ hacker-pod       │   ─X─→    │ db-pod           │   │ ❌ Bloqueado
│  │ (label: untrusted)│           │ (label: backend) │   │
│  └──────────────────┘           └──────────────────┘   │
│                                                           │
│ (Solo si aplicamos una NetworkPolicy)                    │
└─────────────────────────────────────────────────────────┘
```

**Flujo típico con NetworkPolicy:**

1. Creas una `NetworkPolicy` con etiqueta `namespaceSelector: role: backend` en `Ingress`
2. Los pods con esa etiqueta pueden entrar al puerto 5432
3. Cualquier otro pod recibe TCP RST o timeout (conexión rechazada)
4. Los logs de denegate se escriben en `kube-apiserver` (si auditoria está habilitada)

---

## 4. Protocolos y Puertos Comunes

En NetworkPolicies, especificas protocolo + puerto para cada regla:

| Servicio | Puerto | Protocolo | Típicamente Desde |
|----------|--------|-----------|------------------|
| **PostgreSQL** | 5432 | TCP | backend pods en namespace: production |
| **Redis** | 6379 | TCP | app pods, cache services |
| **DNS (CoreDNS)** | 53 | UDP | todos (sin DNS, descubrimiento falla) |
| **HTTPS Ingress** | 443 | TCP | INTERNET (ingress controller) |
| **Prometheus** | 9090 | TCP | monitoring namespace |
| **Etcd** | 2379 | TCP | solo control plane (muy restrictivo) |

```yaml
# Ejemplo: Permitir solo PostgreSQL desde backend pods
spec:
  policyTypes:
    - Ingress
  podSelector:
    matchLabels:
      app: postgres
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          role: backend
    - podSelector:
        matchLabels:
          tier: application
    ports:
    - protocol: TCP
      port: 5432
```

---

## 5. Integración con Observabilidad

Cuando deniegas tráfico, ¿cómo lo vemos?

- **Logs de Ingress Controller:** `kubectl logs -f <ingress-pod>` te muestra qué solicitudes HTTP fueron rechazadas
- **Logs de CNI:** Si usas Cilium, tienes visibilidad L7 automática (qué usuario, qué endpoint, qué error)
- **Prometheus + Grafana:** Puedes graficar tráfico permitido vs denegado por pod/namespace
- **Auditoría de Kubernetes:** Si habilitaste audit logging, tendrás registro de intentos de conexión

---

## 6. Laboratorio

Para completar esta parte, sigue el [Laboratorio de la clase 3.2](../02-laboratorio/laboratorio-clase-3-2.md). Allí encontrarás todos los pasos, código y procedimientos necesarios para verificar el CNI, implementar NetworkPolicies Default Deny, crear whitelists de Ingress y validar comunicación inter-servicios con DNS.

---

## 7. Reto de ingeniería o pregunta de reflexión

**El escenario:**

Tu organización implementó una `NetworkPolicy` de Default Deny All en el namespace `production` hace 3 meses. Durante ese tiempo, los equipos de aplicación han desplegado nuevos microservicios sin coordinación centralizada con el equipo de infraestructura.

Hoy, un nuevo microservicio `analytics-processor` fue desplegado, pero **no puede conectarse a la base de datos PostgreSQL en el namespace `data`**. El equipo de aplicación reporta: *"Fue hace meses que funcionaba todo, ¿por qué ahora no?"*

**Para debatir en clase:**

1. ¿Cómo diseñarías un sistema de approval/governance para que las NetworkPolicies cambien solo con validación del equipo de infraestructura? ¿Qué herramientas (GitOps, admission webhooks, OPA) facilitarían esto?

2. Si la conexión debe ser `analytics-processor` (en `production`) → PostgreSQL (en `data`), escribe la `NetworkPolicy` que permitiría exactamente esa comunicación sin exponer el puerto 5432 a otros servicios.

3. ¿Cómo habrías detectado este problema **antes** de que el analytics-processor fuera desplegado en producción? Propón una estrategia de testing de NetworkPolicies en staging.
