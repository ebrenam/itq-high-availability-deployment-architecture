# 3.1 Balanceo de Carga y Acceso Externo

En la sesión anterior analizamos cómo externalizar configuraciones y escalar réplicas dinámicamente con _ConfigMaps_, _Secrets_ y _HPA_, y ahora en esta sesión llevaremos ese conocimiento a la práctica al explorar _Services_, _Ingress_ y _Load Balancers_ para exponer nuestro clúster.

## 1. Explicación conceptual

En Kubernetes, los _pods_ son efímeros. Tienen direcciones IP dinámicas que cambian cada vez que un _pod_ se destruye, escala o se reprograma en otro nodo. Si intentaras conectar un cliente externo directamente a la IP de un _pod_, el enlace se rompería en cuestión de minutos.

Para resolver este problema de direccionamiento inestable, Kubernetes abstrae la capa de red mediante dos primitivas fundamentales: los **Services** y los controladores de **Ingress**.

```text
[ Cliente Externo ]
        │
        ▼
[ Ingress Controller ] (L7: Rutas, SSL/TLS, Dominios)
        │
        ▼
[ Kubernetes Service ] (L4: IP estable interna + Selector)
        │
   ┌────┴────┐
   ▼         ▼
[ Pod 1 ] [ Pod 2 ]  (L3: IPs dinámicas en la red overlay)
```

### 1.1 La capa de red de capa 4: Kubernetes services

Un _Service_ es una abstracción que define un conjunto lógico de _pods_ y una política para acceder a ellos mediante etiquetas (_labels_). Funciona como un balanceador de carga interno de capa 4 (TCP/UDP) con una IP virtual fija (_ClusterIP_).

Existen cuatro tipos de objetos _Service_:

- **`ClusterIP` (Por defecto):** Expone el servicio en una IP interna exclusiva del clúster. Es inalcanzable desde el exterior y se utiliza para la comunicación privada entre microservicios (por ejemplo, de una API a su base de datos).

- **`NodePort`:** Expone el servicio en un puerto estático (por defecto entre `30000-32767`) en la IP de cada nodo del clúster. Sirve como puente básico hacia el exterior, pero no es recomendable para producción debido a la gestión de puertos y falta de nombres de dominio.

- **`LoadBalancer`:** Integra el clúster con la API de un proveedor _cloud_ (OCI, AWS, GCP) para aprovisionar un balanceador de carga externo con IP pública. Este asigna el tráfico automáticamente a los puertos `NodePort` correspondientes.

- **`ExternalName`:** Mapea el servicio a un nombre DNS externo (mediante un registro `CNAME`), sin usar _selectors_ ni _pods_ locales.

### 1.2 La capa de enrutamiento de capa 7: Ingress y API gateways

Aprovisionar un objeto `LoadBalancer` por cada microservicio en producción resulta costoso e ineficiente. Aquí entra el recurso **`Ingress`**.

Un _Ingress_ opera en la capa 7 del modelo OSI (HTTP/HTTPS) y actúa como un punto de entrada único para el clúster. Administra:

- Enrutamiento basado en rutas (_path-based routing_, ej. `/api/v1/users`).

- Enrutamiento basado en nombres de dominio (_host-based routing_, ej. `api.empresa.com`).

- Terminación de certificados SSL/TLS en el borde.

- Balanceo de carga avanzado y reescritura de URLs.

> **Nota arquitectónica:** El recurso `Ingress` por sí solo es únicamente una especificación de reglas. Requiere un **Ingress Controller** (como NGINX Ingress Controller, Traefik o HAProxy) ejecutándose en el clúster para procesar esas reglas y dirigir el tráfico. Para escenarios más complejos que requieren gestión de cuotas (_rate limiting_), autenticación OAuth2 o métricas detalladas, se integran **API Gateways** (como Kong o Envoy).

---

## 2. Analogía del mundo real

Imagina un gran edificio corporativo de oficinas:

- **Los Pods:** Son los empleados trabajando en sus escritorios. Cambian de oficina, entran y salen constantemente.

- **ClusterIP:** Es la extensión telefónica interna. Si la extensión del área de finanzas es la `401`, llamas a ese número sin importar qué empleado conteste la llamada.

- **NodePort:** Es abrir una ventana en el piso 3 y colocar una escalera metálica que da a la calle. Cualquiera puede subir directamente a esa oficina específica, pero es incómodo, inseguro y se ve mal arquitectónicamente.

- **LoadBalancer:** Es contratar a un guardia de seguridad privado afuera del edificio que recibe a la gente en la banqueta y la canaliza por la escalera metálica correcta.

- **Ingress Controller:** Es la recepción principal del edificio en la planta baja. Una sola puerta de entrada con un recepcionista que lee tu solicitud: si pides hablar con "Ventas", te dirige al ascensor B (_path-based_); si muestras una identificación VIP con acceso especial, te envía al piso ejecutivo con cifrado de seguridad (_TLS/SSL termination_).

---

## 3. Arquitectura Completa: Flujo de Tráfico

```text
                    INTERNET (HTTPS:443)
                            │
                            │ checkout.local
                            ▼
              ┌──────────────────────────────┐
              │ NGINX Ingress Controller      │
              │ - TLS Termination             │
              │ - Host-based routing          │
              │ - Path-based routing          │
              └───────────┬────────────────────┘
                          │
               ┌──────────┼──────────┐
               │                     │
               ▼ HTTP:8080           ▼ HTTP:8080
          ┌─────────────┐       ┌──────────────┐
          │   Service   │       │   Service    │
          │  payment    │       │  catalog     │
          │(ClusterIP)  │       │ (ClusterIP)  │
          └──────┬──────┘       └──────┬───────┘
                 │                     │
             ┌───┴───┐            ┌───┴────┐
             ▼       ▼            ▼        ▼
           ┌───┐  ┌───┐       ┌────┐   ┌────┐
           │ P1│  │ P2│       │ P3 │   │ P4 │
           └───┘  └───┘       └────┘   └────┘
        (IPs dinámicas cambian constantemente)
```

---

## 4. Caso de Uso Real: Plataforma E-commerce

Imagina una plataforma de e-commerce con 3 microservicios:

| Servicio | Tipo | Acceso | Propósito |
|----------|------|--------|-----------|
| **payment-service** | ClusterIP | Ingress → HTTPS | Procesar pagos (acceso externo) |
| **catalog-service** | ClusterIP | payment-service → HTTP | Datos de productos (privado) |
| **inventory-service** | ClusterIP | payment-service → HTTP | Stock de productos (privado) |

Con **un solo Ingress Controller**, exponemos payment-service con TLS, mientras catalog e inventory permanecen privadas (solo accesibles internamente).

```
Cliente navegando checkout.local (HTTPS):
    │
    └──→ Ingress Controller (NGINX)
            │
            └──→ payment-service (Pod 1/2)
                    │
                    ├──→ catalog-service (privado)
                    └──→ inventory-service (privado)
```

Sin Ingress, necesitaríamos:
- ❌ 3 LoadBalancers externos (costoso)
- ❌ Gestionar 3 IPs públicas diferentes
- ❌ 3 certificados TLS separados
- ❌ Los clientes necesitarían saber 3 direcciones diferentes

Con Ingress:
- ✅ 1 Ingress Controller
- ✅ 1 dominio (checkout.local)
- ✅ 1 certificado TLS centralizado
- ✅ Los clientes ven solo el dominio público

---

## 5. Comparación: Alternativas Históricas

### Infraestructura Tradicional (Pre-Kubernetes)
```
Monolítico
└─ 1 aplicación = 1 servidor = 1 IP pública = 1 DNS
   Escalado manual, sin service discovery
```

### Kubernetes Sin Ingress (Solo ClusterIP + NodePort)
```
Múltiples servicios, pero sin unificación:
└─ Cada NodePort = puerto diferente (30000, 30001, 30002...)
└─ Cliente debe saber puertos específicos
└─ Sin gestión centralizada de TLS
└─ Sin enrutamiento sofisticado
```

### Kubernetes + Ingress (Mejor Práctica Moderna)
```
Múltiples servicios, acceso unificado:
└─ UN Ingress Controller = múltiples dominios/rutas
└─ Gestión centralizada de TLS
└─ Cliente ve nombres amigables (checkout.local)
└─ Escala transparentemente sin cambiar cliente
```

---

## 6. Laboratorio

Para completar esta parte, sigue el [Laboratorio de la clase 3.1](../02-laboratorio/laboratorio-clase-3-1.md). Allí encontrarás todos los pasos, código y procedimientos necesarios para instalar NGINX Ingress Controller, crear certificados TLS, desplegar manifests y validar acceso seguro desde clientes externos.

---

## 7. Reto de ingeniería o pregunta de reflexión

**El escenario:**

Tu empresa tiene una arquitectura con 5 microservicios desplegados en Kubernetes. Actualmente todos están expuestos a través de un único Ingress Controller NGINX usando terminación TLS en el borde:

```
Cliente → HTTPS:443 → Ingress Controller → HTTP:8080 → Pods (sin cifrado interno)
```

El equipo de auditoría identifica que el tráfico interno entre el Ingress Controller y los Pods viaja en HTTP plano, lo cual viola la normativa de seguridad PCI-DSS que requiere **cifrado de extremo a extremo**.

**Para debatir en clase:**

1. ¿Qué patrón de seguridad de red (TLS Passthrough vs. mTLS) implementarías para garantizar que cada Pod tenga su propio certificado TLS y el tráfico entre Ingress y Pods también sea cifrado? ¿Cuáles serían los trade-offs en complejidad y rendimiento?

2. Si implementas mTLS nativa en Kubernetes (Service Mesh como Istio o Linkerd), ¿qué ventaja adicional obtienes comparado con solo usar certificados auto-firmados en cada Pod?

3. ¿Cómo balancearías la seguridad (cifrado total) con la observabilidad (poder ver el tráfico en logs del Ingress)?
