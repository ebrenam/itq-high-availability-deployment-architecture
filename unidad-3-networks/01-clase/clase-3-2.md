# 3.2 Redes del Clúster y Políticas de Comunicación

En la sesión anterior analizamos cómo gestionar el tráfico de entrada mediante _Services_, _Ingress_ y terminación TLS, y ahora en esta sesión llevaremos ese conocimiento a la práctica al explorar _NetworkPolicies_, el CNI y el aislamiento del tráfico interno.

### 1. Explicación conceptual

A diferencia de la infraestructura tradicional donde las máquinas virtuales se aíslan con VLANs o subredes fijas, Kubernetes utiliza un modelo plano de red (_flat network_) gobernado por tres reglas fundamentales:

1. Todo _pod_ obtiene su propia IP en una red _overlay_ accesible por todo el clúster.

2. Todos los _pods_ pueden comunicarse con cualquier otro _pod_ en el clúster **sin necesidad de NAT** (_Network Address Translation_).

3. Todos los nodos pueden comunicarse con todos los _pods_ del clúster sin NAT.

#### El motor subyacente: Container Network Interface (CNI)

Kubernetes no gestiona las interfaces de red ni las tablas de ruteo directamente; delega esta función a un _plugin_ de **CNI**:

- **Flannel:** Plugin simple de capa 2 (L2) que crea una red _overlay_ con encapsulamiento VXLAN. Es ligero, pero no soporta _NetworkPolicies_.

- **Calico:** Plugin de capa 3 (L3) altamente escalable que utiliza BGP (_Border Gateway Protocol_) para ruteo directo o encapsulamiento IP-in-IP/VXLAN. Implementa reglas de seguridad nativas.

- **Cilium:** Plugin de última generación respaldado por **eBPF** (_Extended Berkeley Packet Filter_). Procesa paquetes directamente en el Kernel de Linux, evitando la sobrecarga de _iptables_ y ofreciendo observabilidad y seguridad en capa 7 (L7).

#### Seguridad con modelo Zero Trust: NetworkPolicies

Por defecto, la red de Kubernetes es **plana y totalmente abierta**: cualquier _pod_ en cualquier _namespace_ puede hablar con cualquier otro _pod_. Para implementar el principio de mínimo privilegio (_Zero Trust_), declaramos objetos **`NetworkPolicy`**.

Una `NetworkPolicy` actúa como un _firewall_ distribuido basado en etiquetas (_labels_) y _namespaces_:

- **`Ingress`:** Controla qué tráfico entrante se permite hacia los _pods_ seleccionados.

- **`Egress`:** Controla qué tráfico saliente se permite desde los _pods_ seleccionados hacia otros _pods_, rangos CIDR o servicios externos.

#### Descubrimiento de servicios con CoreDNS

Para evitar acoplarse a IPs dinámicas, el clúster integra **CoreDNS**. Cada vez que creas un `Service`, CoreDNS le asigna un nombre de dominio completamente calificado (_FQDN_):

```text
$$\text{<nombre-servicio>.<namespace>.svc.cluster.local}$$
```

Si dos microservicios conviven en el mismo _namespace_, basta con invocar `<nombre-servicio>:<puerto>`.

### 2. Analogía del mundo real

Imagina un gran edificio corporativo _open space_ sin paredes físicas interiores:

- **Modelo de red plano (IP por pod):** Todos los empleados caminan por el mismo pasillo principal. Cuestión de tiempo para que cualquiera pueda ir al escritorio de quien sea sin restricciones.

- **El CNI (El sistema de ventilación y accesos):**

    - _Flannel_ es poner tuberías de aire estándar. Cumple con llevar oxígeno pero no tiene puertas de seguridad.

    - _Calico_ es poner torniquetes con tarjetas magnéticas en cada pasillo.

    - _Cilium_ es colocar escáneres de reconocimiento facial con rayos X (eBPF) instalados directamente en las puertas; detectan si alguien lleva algo no autorizado sin detener el flujo de personas.

- **NetworkPolicies (Tarjetas de acceso VIP):** Por defecto, el becario de marketing puede entrar al cuarto del servidor de la nómina de la empresa. Al aplicar una `NetworkPolicy`, colocas un lector biométrico: solo los empleados etiquetados como `role: finance` pueden traspasar la puerta del cuarto `namespace: accounting`.

- **CoreDNS (El directorio telefónico interno):** Nadie en la empresa se memoriza las extensiones de 10 dígitos de sus compañeros. Abres la libreta y buscas "Servicio de Inventario", e internamente el directorio te enlaza con la extensión actual de la persona, cambie de escritorio o no.

### 3. Desglose técnico paso a paso

En este ejercicio aislaremos un microservicio de base de datos (`db-service`) para que **únicamente** acepte tráfico en el puerto `5432` proveniente de microservicios autenticados etiquetados como `role: backend`, bloqueando cualquier otro acceso.

#### Paso 1: Crear los Namespaces para aislar entornos

Crea el archivo `01-namespaces.yaml`:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: prod-backend
  labels:
    environment: production
---
apiVersion: v1
kind: Namespace
metadata:
  name: prod-db
  labels:
    environment: production
```

Aplica el manifiesto:

```bash
kubectl apply -f 01-namespaces.yaml
```

#### Paso 2: Desplegar la base de datos y la aplicación

Crea el archivo `02-workloads.yaml`:

```yaml
# Microservicio de Base de Datos
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgres-db
  namespace: prod-db
spec:
  replicas: 1
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
      - name: postgres
        image: postgres:15-alpine
        env:
        - name: POSTGRES_PASSWORD
          value: "SecretPass123"
        ports:
        - containerPort: 5432
---
apiVersion: v1
kind: Service
metadata:
  name: db-service
  namespace: prod-db
spec:
  type: ClusterIP
  ports:
  - port: 5432
    targetPort: 5432
  selector:
    app: postgres
---
# Microservicio Autorizado en Backend
apiVersion: apps/v1
kind: Deployment
metadata:
  name: order-service
  namespace: prod-backend
spec:
  replicas: 1
  selector:
    matchLabels:
      app: order-service
  template:
    metadata:
      labels:
        app: order-service
        role: backend
    spec:
      containers:
      - name: order-app
        image: busybox
        command: ["sh", "-c", "sleep 3600"]
```

Aplica la configuración en el clúster:

```bash
kubectl apply -f 02-workloads.yaml
```

#### Paso 3: Definir la NetworkPolicy de aislamiento estricto (Default Deny + Whitelist)

Crea el archivo `03-network-policy.yaml`. Denegaremos todo el tráfico por defecto hacia la base de datos y permitiremos el acceso **exclusivamente** desde pods con la etiqueta `role: backend` en el namespace `prod-backend`, además de habilitar consultas DNS (`Egress` puerto 53).

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-only-backend-to-db
  namespace: prod-db
spec:
  podSelector:
    matchLabels:
      app: postgres
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          environment: production
      podSelector:
        matchLabels:
          role: backend
    ports:
    - protocol: TCP
      port: 5432
```

Aplica la política de seguridad:

```bash
kubectl apply -f 03-network-policy.yaml
```

#### Paso 4: Pruebas de conectividad y verificación de diagnóstico

1. **Prueba permitida:** Conéctate desde el pod autorizado en `prod-backend` hacia la base de datos usando CoreDNS:

    ```bash
    # Obtenemos el nombre del pod del backend
    BACKEND_POD=$(kubectl get pod -n prod-backend -l app=order-service -o jsonpath='{.items[0].metadata.name}')
    
    # Probamos conexión TCP al puerto 5432 con el FQDN de CoreDNS
    kubectl exec -it $BACKEND_POD -n prod-backend -- nc -zv -w 3 db-service.prod-db.svc.cluster.local 5432
    ```
    
    _Resultado esperado:_ `db-service.prod-db.svc.cluster.local (10.xx.xx.xx:5432) open`
    
2. **Prueba bloqueada:** Ejecuta un pod no autorizado (por ejemplo, desde el namespace `default`) e intenta acceder a la base de datos:
    
    
    ```bash
    kubectl run hacker-pod --image=busybox -n default --rm -it -- restart=Never -- nc -zv -w 3 db-service.prod-db.svc.cluster.local 5432
    ```
    
    _Resultado esperado:_ `nc: download/connect timeout` (El tráfico es descartado silenciosamente por el CNI).

### 4. Reto de ingeniería o pregunta de reflexión

**El escenario:**

Un equipo de desarrollo desplegó una nueva aplicación Java en el _namespace_ `finance`. Configuraron una `NetworkPolicy` de salida (_Egress_) extremadamente estricta para bloquear cualquier comunicación no deseada hacia el exterior:

```yaml
spec:
  podSelector:
    matchLabels:
      app: payment-processor
  policyTypes:
  - Egress
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: ledger-db
```

Inmediatamente después de aplicar esta política, la aplicación `payment-processor` comenzó a arrojar excepciones de conexión `java.net.UnknownHostException: ledger-db.finance.svc.cluster.local` y dejó de funcionar por completo, a pesar de que la regla de _Egress_ permite el tráfico directo hacia la etiqueta `app: ledger-db`.

**Preguntas para debate:**

1. ¿Por qué la aplicación perdió la capacidad de resolver el FQDN de la base de datos a pesar de que la regla explícitamente permite conectarse al _pod_ de la base de datos?

2. ¿Qué puerto y protocolo (asociados a CoreDNS) olvidados en la sección de _Egress_ causaron esta falla en la resolución de nombres?

3. Si el clúster estuviera utilizando un CNI básico como **Flannel**, ¿por qué la `NetworkPolicy` anterior habría sido completamente ignorada, permitiendo que todo el tráfico pase sin restricciones?

> "En la sesión anterior analizamos cómo asegurar la conectividad interna mediante el CNI, CoreDNS y _NetworkPolicies_, y ahora en esta sesión llevaremos ese conocimiento a la práctica al explorar RBAC, _ServiceAccounts_ y mecanismos de autenticación."