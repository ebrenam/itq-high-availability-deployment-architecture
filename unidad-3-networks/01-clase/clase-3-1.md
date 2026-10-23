# 3.1 Balanceo de Carga y Acceso Externo

En la sesión anterior analizamos cómo externalizar configuraciones y escalar réplicas dinámicamente con _ConfigMaps_, _Secrets_ y _HPA_, y ahora en esta sesión llevaremos ese conocimiento a la práctica al explorar _Services_, _Ingress_ y _Load Balancers_ para exponer nuestro clúster.

## Explicación conceptual

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

### 1. La capa de red de capa 4: Kubernetes Services

Un _Service_ es una abstracción que define un conjunto lógico de _pods_ y una política para acceder a ellos mediante etiquetas (_labels_). Funciona como un balanceador de carga interno de capa 4 (TCP/UDP) con una IP virtual fija (_ClusterIP_).

Existen cuatro tipos de objetos _Service_:

- **`ClusterIP` (Por defecto):** Expone el servicio en una IP interna exclusiva del clúster. Es inalcanzable desde el exterior y se utiliza para la comunicación privada entre microservicios (por ejemplo, de una API a su base de datos).

- **`NodePort`:** Expone el servicio en un puerto estático (por defecto entre `30000-32767`) en la IP de cada nodo del clúster. Sirve como puente básico hacia el exterior, pero no es recomendable para producción debido a la gestión de puertos y falta de nombres de dominio.

- **`LoadBalancer`:** Integra el clúster con la API de un proveedor _cloud_ (OCI, AWS, GCP) para aprovisionar un balanceador de carga externo con IP pública. Este asigna el tráfico automáticamente a los puertos `NodePort` correspondientes.

- **`ExternalName`:** Mapea el servicio a un nombre DNS externo (mediante un registro `CNAME`), sin usar _selectors_ ni _pods_ locales.

### 2. La capa de enrutamiento de capa 7: Ingress y API Gateways

Aprovisionar un objeto `LoadBalancer` por cada microservicio en producción resulta costoso e ineficiente. Aquí entra el recurso **`Ingress`**.

Un _Ingress_ opera en la capa 7 del modelo OSI (HTTP/HTTPS) y actúa como un punto de entrada único para el clúster. Administra:

- Enrutamiento basado en rutas (_path-based routing_, ej. `/api/v1/users`).

- Enrutamiento basado en nombres de dominio (_host-based routing_, ej. `api.empresa.com`).

- Terminación de certificados SSL/TLS en el borde.

- Balanceo de carga avanzado y reescritura de URLs.

> **Nota arquitectónica:** El recurso `Ingress` por sí solo es únicamente una especificación de reglas. Requiere un **Ingress Controller** (como NGINX Ingress Controller, Traefik o HAProxy) ejecutándose en el clúster para procesar esas reglas y dirigir el tráfico. Para escenarios más complejos que requieren gestión de cuotas (_rate limiting_), autenticación OAuth2 o métricas detalladas, se integran **API Gateways** (como Kong o Envoy).

## Analogía del mundo real

Imagina un gran edificio corporativo de oficinas:

- **Los Pods:** Son los empleados trabajando en sus escritorios. Cambian de oficina, entran y salen constantemente.

- **ClusterIP:** Es la extensión telefónica interna. Si la extensión del área de finanzas es la `401`, llamas a ese número sin importar qué empleado conteste la llamada.

- **NodePort:** Es abrir una ventana en el piso 3 y colocar una escalera metálica que da a la calle. Cualquiera puede subir directamente a esa oficina específica, pero es incómodo, inseguro y se ve mal arquitectónicamente.

- **LoadBalancer:** Es contratar a un guardia de seguridad privado afuera del edificio que recibe a la gente en la banqueta y la canaliza por la escalera metálica correcta.

- **Ingress Controller:** Es la recepción principal del edificio en la planta baja. Una sola puerta de entrada con un recepcionista que lee tu solicitud: si pides hablar con "Ventas", te dirige al ascensor B (_path-based_); si muestras una identificación VIP con acceso especial, te envía al piso ejecutivo con cifrado de seguridad (_TLS/SSL termination_).

## Desglose técnico paso a paso

A continuación, desplegaremos un microservicio de demostración en Quarkus y lo expondremos de forma segura con reglas de dominio, rutas y cifrado SSL/TLS simulado.

### Paso 1: Crear el certificado TLS sintético para el dominio

Para habilitar HTTPS en el _Ingress Controller_, generaremos un par de llaves (certificado y clave privada) y las guardaremos en un objeto `Secret` de tipo `kubernetes.io/tls`.

```bash
# Generar certificado autofirmado para el dominio ficticio
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout app-tls.key -out app-tls.crt \
  -subj "/CN=tienda.local/O=DevOps"

# Crear el Secret en Kubernetes
kubectl create secret tls tienda-tls-secret \
  --key=app-tls.key \
  --cert=app-tls.crt
```

### Paso 2: Configurar los Deployments y Services internos

Crearemos dos microservicios simulados (`frontend` y `catalog`). Ambos usarán la clase `ClusterIP` para permanecer privados dentro del clúster.

Guarda el siguiente manifiesto como `01-apps-and-services.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend-deployment
  labels:
    app: frontend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
    spec:
      containers:
      - name: web
        image: nginxdemos/hello:plain-text
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: frontend-service
spec:
  type: ClusterIP
  selector:
    app: frontend
  ports:
  - port: 80
    targetPort: 80
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: catalog-deployment
  labels:
    app: catalog
spec:
  replicas: 2
  selector:
    matchLabels:
      app: catalog
  template:
    metadata:
      labels:
        app: catalog
    spec:
      containers:
      - name: api
        image: hashicorp/http-echo:latest
        args:
        - "-text=Respuestas desde el Microservicio de Catalogo"
        ports:
        - containerPort: 5678
---
apiVersion: v1
kind: Service
metadata:
  name: catalog-service
spec:
  type: ClusterIP
  selector:
    app: catalog
  ports:
  - port: 80
    targetPort: 5678
```

Aplica la configuración:

```bash
kubectl apply -f 01-apps-and-services.yaml
```

### Paso 3: Definir el objeto Ingress con enrutamiento L7 y TLS

Crea el archivo `02-ingress-rules.yaml` definiendo el enrutamiento por rutas (_path-based_) y la terminación de certificados HTTPS.

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: tienda-ingress
  annotations:
    # Anotación específica para NGINX Ingress Controller
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - tienda.local
    secretName: tienda-tls-secret
  rules:
  - host: tienda.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: frontend-service
            port:
              number: 80
      - path: /catalog
        pathType: Prefix
        backend:
          service:
            name: catalog-service
            port:
              number: 80
```

Aplica el objeto `Ingress`:

```bash
kubectl apply -f 02-ingress-rules.yaml
```

### Paso 4: Pruebas de verificación y consumo del tráfico

1. Obten la IP asignada a tu _Ingress Controller_ (en entornos locales como Minikube, usa `minikube ip`):

    ```bash
    kubectl get ingress tienda-ingress
    ```

2. Mapea la IP a tu archivo de hosts local (`/etc/hosts` en Linux/Mac o `drivers/etc/hosts` en Windows):

    ```text
    192.168.49.2  tienda.local
    ```

3. Realiza las peticiones de prueba verificando el enrutamiento y la terminación de TLS:

    ```bash
    # Probar la ruta raíz (Servicio Frontend)
    curl -k https://tienda.local/
    
    # Probar la ruta del catálogo (Servicio Catalog)
    curl -k https://tienda.local/catalog
    ```

## Reto de ingeniería o pregunta de reflexión

**El escenario:**

Tu empresa tiene una aplicación bancaria crítica desplegada en Kubernetes. Un ingeniero junior configuró el controlador de _Ingress_ para realizar la terminación TLS/SSL en el borde del clúster (el tráfico que llega de los clientes HTTPS se descifra al entrar a la red).

A partir de ese punto, el _Ingress_ reenvía el tráfico internamente a los _pods_ usando HTTP plano sobre el tipo de servicio `ClusterIP`.

El equipo de auditoría e infraestructura emite una alerta roja alegando que el entorno **incumple las normativas de seguridad PCI-DSS**, ya que el tráfico interno dentro de la red del clúster viaja no cifrado (_in-cleartext_).

**Preguntas para debate:**

1. ¿Qué patrón o estrategia de red aplicarías para garantizar cifrado de extremo a extremo (_End-to-End TLS / TLS Passthrough_) desde el cliente externo hasta el _pod_ de Quarkus?

2. ¿Qué impacto en el rendimiento de la CPU del clúster tiene trasladar la carga del descifrado criptográfico desde un solo _Ingress Controller_ hacia cada uno de los _pods_ individuales?

3. En arquitecturas modernas de microservicios, ¿cómo resuelve este problema una Service Mesh (ej. Istio o Linkerd) mediante el concepto de **mTLS** (_mutual TLS_) sin tener que modificar una sola línea de código en la aplicación Java?

> "En la sesión anterior analizamos cómo gestionar el tráfico de entrada mediante _Services_, _Ingress_ y terminación TLS, y ahora en esta sesión llevaremos ese conocimiento a la práctica al explorar _NetworkPolicies_, el CNI y el aislamiento del tráfico interno."