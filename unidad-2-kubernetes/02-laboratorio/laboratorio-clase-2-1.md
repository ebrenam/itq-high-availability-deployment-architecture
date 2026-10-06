# Laboratorio de la clase 2.1: Inspección de Arquitectura y Componentes de Kubernetes

## Objetivo del laboratorio y escenario real

**El escenario:** Trabajas como _Cloud Engineer_ en una organización que está migrando sus aplicaciones a Kubernetes. Antes de desplegar microservicios en producción, necesitas comprender la arquitectura interna del clúster, cómo interactúan los componentes del _Control Plane_ con los _Worker Nodes_, y validar que el modelo de red plana funciona correctamente.

**El objetivo:** Inspeccionarás los componentes del Control Plane, rastrearás el ciclo de vida completo de un _Deployment_, validarás la asignación de IPs de red plana entre Pods y comprobarás la conectividad directa sin NAT.

**Regla de continuidad:** Completa este laboratorio antes de continuar con [Laboratorio 2.2](./laboratorio-clase-2-2.md). Sin comprender la arquitectura interna, no podrás diagnosticar problemas de despliegues y de red posteriores.

## Prerequisitos y stack tecnológico

Antes de iniciar, verifica que tu estación de trabajo cuente con las siguientes herramientas instaladas y funcionales en tu terminal:

### Requisitos comunes (Linux, macOS y Windows)

- **Minikube** v1.32+ (o **Kind** v0.20+) - clúster Kubernetes local
- **kubectl** CLI instalado y configurado
- **curl** para pruebas de conectividad HTTP

### Requisitos específicos por SO

![linux](images/linux.png) **Linux/macOS:**

- Terminal bash nativa
- Herramientas Unix: `grep`, `watch`, `grep`, `awk`

![win](images/windows.png) **Windows:**

- **PowerShell 5.0+** (recomendado)
- `curl.exe` (incluido en Windows 10.1903+)

```bash
# Verificación de herramientas en el entorno local
kubectl version --client && minikube version
```

## Punto de partida

Trabaja desde un clúster Kubernetes local que esté funcionando. Si no tienes uno, inícialo con:

```bash
minikube start --cpus=4 --memory=4096
```

Verifica que el clúster esté listo:

```bash
kubectl cluster-info
kubectl get nodes
```

## Paso 1: Inspeccionar los componentes del Control Plane

El _Control Plane_ es el cerebro del clúster. Todos sus componentes se ejecutan en el _namespace_ `kube-system`.

### ![linux](images/linux.png) Instrucciones para Linux/macOS

```bash
# Obtener los componentes del plano de control en el namespace kube-system
kubectl get pods -n kube-system -o wide

# Inspeccionar el estado de los componentes del sistema
kubectl get componentstatuses
```

### ![win](images/windows.png) Instrucciones para Windows

```powershell
# Obtener los componentes del plano de control
kubectl get pods -n kube-system -o wide

# Inspeccionar el estado
kubectl get componentstatuses
```

### Qué observar

```bash
NAME                             READY   STATUS    RESTARTS
coredns-5d78c1869d-9xvhc         1/1     Running   0
etcd-minikube                    1/1     Running   0
kube-apiserver-minikube          1/1     Running   0
kube-controller-manager-mink...  1/1     Running   0
kube-proxy-8xh2x                 1/1     Running   0
kube-scheduler-minikube          1/1     Running   0
storage-provisioner              1/1     Running   0
```

**Interpretación:**

- **etcd:** Base de datos de Kubernetes (la fuente única de la verdad)
- **kube-apiserver:** Punto de entrada de todas las solicitudes (API REST)
- **kube-scheduler:** Asigna Pods a nodos
- **kube-controller-manager:** Reconcilia estado deseado vs. actual
- **kube-proxy:** Gestiona reglas de red en cada nodo
- **coredns:** Servicio DNS interno del clúster

Si todos están en `Running` y `Ready`, tu Control Plane está saludable.

---

## Paso 2: Rastrear el ciclo de vida de un Deployment

Veremos exactamente cómo interactúan el API Server, Scheduler, Controller Manager y Kubelet cuando creamos un Deployment.

### ![linux](images/linux.png) Instrucciones para Linux/macOS

Crea un archivo `demo-deployment.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: core-demo-quarkus
  namespace: default
  labels:
    app: core-demo
spec:
  replicas: 2
  selector:
    matchLabels:
      app: core-demo
  template:
    metadata:
      labels:
        app: core-demo
    spec:
      containers:
        - name: quarkus-app
          image: <tu-usuario-dockerhub>/catalog-service:1.0.0
          ports:
            - containerPort: 8080
              name: http
          resources:
            requests:
              memory: "128Mi"
              cpu: "100m"
            limits:
              memory: "256Mi"
              cpu: "250m"
```

Aplica el manifiesto y observa la secuencia de eventos:

```bash
# Aplicar la especificación declarativa en el API Server
kubectl apply -f demo-deployment.yaml

# Ver eventos en tiempo real (sorted por timestamp)
kubectl get events --sort-by='.metadata.creationTimestamp' -n default
```

### ![win](images/windows.png) Instrucciones para Windows

Crea el mismo archivo `demo-deployment.yaml` y ejecuta:

```powershell
# Aplicar
kubectl apply -f demo-deployment.yaml

# Ver eventos
kubectl get events --sort-by='.metadata.creationTimestamp' -n default
```

### Qué sucede internamente (secuencia esperada)

```bash
REASON                MESSAGE
SuccessfulCreate      Created pod: core-demo-quarkus-xxx-rdxwk
ScalingReplicaSet     Scaled up replica set core-demo-quarkus-xxx to 2
SuccessfulCreate      Created pod: core-demo-quarkus-xxx-kj5hk
Scheduled             Successfully assigned default/core-demo-quarkus-xxx-kj5hk to minikube
Scheduled             Successfully assigned default/core-demo-quarkus-xxx-rdxwk to minikube
Pulling               Pulling image "tu-usuario/catalog-service:1.0.0"
Pulling               Pulling image "tu-usuario/catalog-service:1.0.0"
Pulled                Successfully pulled image "tu-usuario/catalog-service:1.0.0"
Created               Created container quarkus-app
Started               Started container quarkus-app
Pulled                Successfully pulled image "tu-usuario/catalog-service:1.0.0"
Created               Created container quarkus-app
Started               Started container quarkus-app
```

**Nota:** Los eventos se generan de forma intercalada para ambos Pods. El Kubelet descarga la imagen para el primer Pod (~9s), luego para el segundo Pod (~0.8s, más rápido porque está en caché).

**Análisis paso a paso:**

1. **API Server** recibe `kubectl apply` con el YAML, valida la sintaxis y lo almacena en etcd
2. **Deployment Controller** observa el Deployment, detecta que faltan 2 Pods, crea un ReplicaSet
3. **ReplicaSet Controller** observa que el ReplicaSet necesita 2 réplicas, crea 2 especificaciones de Pod (evento: `SuccessfulCreate` × 2)
4. **ReplicaSet Controller** escala el ReplicaSet a 2 (evento: `ScalingReplicaSet`)
5. **Scheduler** observa los 2 Pods sin nodo asignado, los asigna al nodo más saludable (evento: `Scheduled` × 2)
6. **Kubelet** (en el nodo) observa los Pods asignados a su nodo, descarga la imagen (evento: `Pulling` × 2)
7. **Kubelet** descomprime y crea el contenedor (evento: `Created`)
8. **Kubelet** inicia el contenedor (evento: `Started`)

**Resultado:** El flujo completo demuestra el **modelo declarativo en acción**: declaras el *estado deseado* (2 Pods), y Kubernetes automáticamente reconcilia hasta alcanzarlo.

---

## Paso 3: Validar la asignación de IPs y red plana de Pods

Kubernetes asigna una IP única a cada Pod. Todos los Pods pueden comunicarse entre sí sin NAT.

### ![linux](images/linux.png) Instrucciones para Linux/macOS

```bash
# Ver las IPs asignadas a cada Pod y su nodo
kubectl get pods -l app=core-demo -o custom-columns=NAME:.metadata.name,IP:.status.podIP,NODE:.spec.nodeName,STATUS:.status.phase

# Captura el nombre e IP de ambos Pods
POD_1_NAME=$(kubectl get pods -l app=core-demo -o jsonpath='{.items[0].metadata.name}')
POD_1_IP=$(kubectl get pods -l app=core-demo -o jsonpath='{.items[0].status.podIP}')
POD_2_NAME=$(kubectl get pods -l app=core-demo -o jsonpath='{.items[1].metadata.name}')
POD_2_IP=$(kubectl get pods -l app=core-demo -o jsonpath='{.items[1].status.podIP}')

echo "Pod 1: $POD_1_NAME con IP $POD_1_IP"
echo "Pod 2: $POD_2_NAME con IP $POD_2_IP"
```

### ![win](images/windows.png) Instrucciones para Windows

```powershell
# Ver IPs
kubectl get pods -l app=core-demo -o custom-columns=NAME:.metadata.name,IP:.status.podIP,NODE:.spec.nodeName

# Captura valores de ambos Pods
$POD_1_NAME = kubectl get pods -l app=core-demo -o jsonpath='{.items[0].metadata.name}'
$POD_1_IP = kubectl get pods -l app=core-demo -o jsonpath='{.items[0].status.podIP}'
$POD_2_NAME = kubectl get pods -l app=core-demo -o jsonpath='{.items[1].metadata.name}'
$POD_2_IP = kubectl get pods -l app=core-demo -o jsonpath='{.items[1].status.podIP}'

Write-Host "Pod 1: $POD_1_NAME con IP $POD_1_IP"
Write-Host "Pod 2: $POD_2_NAME con IP $POD_2_IP"
```

### Qué observar

```bash
NAME                      IP           NODE       STATUS
core-demo-quarkus-xxx-1   10.244.0.5   minikube   Running
core-demo-quarkus-xxx-2   10.244.0.6   minikube   Running
```

Cada Pod tiene una IP en el rango `10.244.x.x` (asignada por la CNI de Kubernetes).

---

## Paso 4: Probar conectividad directa entre Pods (red plana)

Verificaremos que Pod 2 puede alcanzar Pod 1 por su IP sin necesidad de NAT o puertos especiales.

### ![linux](images/linux.png) Instrucciones para Linux/macOS

```bash
# Usar el Pod 2 para hacer ping a la IP del Pod 1 (aunque ping usa ICMP, probamos DNS + HTTP)
POD_1_IP=$(kubectl get pods -l app=core-demo -o jsonpath='{.items[0].status.podIP}')
POD_2_NAME=$(kubectl get pods -l app=core-demo -o jsonpath='{.items[1].metadata.name}')

# Ejecutar curl desde Pod 2 hacia Pod 1
kubectl exec -it $POD_2_NAME -- curl -s http://$POD_1_IP:8080/health

# Resultado esperado: JSON de salud (HTTP 200)
```

### ![win](images/windows.png) Instrucciones para Windows

```powershell
$POD_1_IP = kubectl get pods -l app=core-demo -o jsonpath='{.items[0].status.podIP}'
$POD_2_NAME = kubectl get pods -l app=core-demo -o jsonpath='{.items[1].metadata.name}'

kubectl exec -it $POD_2_NAME -- curl -s http://$POD_1_IP:8080/health
```

### Qué observar

```json
{"status":"UP","checks":[]}
```

**Interpretación:**

- Pod 2 (Pod cliente) pudo alcanzar Pod 1 (Pod servidor) por su IP privada
- **No hay NAT:** La comunicación es directa, punto a punto
- **IP plana funcional:** El complemento CNI (Flannel, Calico, etc.) está permitiendo esta comunicación

Este es el principio fundamental de Kubernetes: todos los Pods son alcanzables directamente.

---

## Paso 5: Inspeccionar ReplicaSets y Control de réplicas

Verifica cómo el Deployment administra los ReplicaSets subyacentes.

### ![linux](images/linux.png) Instrucciones para Linux/macOS

```bash
# Ver el ReplicaSet creado por el Deployment
kubectl get replicasets -l app=core-demo

# Ver los detalles del ReplicaSet
kubectl describe replicaset $(kubectl get replicasets -l app=core-demo -o jsonpath='{.items[0].metadata.name}')

# Ver la jerarquía: Deployment → ReplicaSet → Pods
kubectl get deployment,replicaset,pods -l app=core-demo
```

### ![win](images/windows.png) Instrucciones para Windows

```powershell
# Ver ReplicaSets
kubectl get replicasets -l app=core-demo

# Ver jerarquía
kubectl get deployment,replicaset,pods -l app=core-demo -o wide
```

### Qué observar

```bash
NAME                       DESIRED   CURRENT   READY
core-demo-quarkus-xxx      2         2         2
```

**Jerarquía:**

```text
Deployment (core-demo-quarkus)
  └─ ReplicaSet (core-demo-quarkus-xxx)
     ├─ Pod (core-demo-quarkus-xxx-abc1)
     └─ Pod (core-demo-quarkus-xxx-abc2)
```

El Deployment administra el ReplicaSet, que a su vez garantiza las réplicas de Pods.

---

## Guía de Troubleshooting

### Problema 1: Los Pods quedan en estado `Pending`

**Síntoma:** `kubectl get pods` muestra status `Pending`.

**Causa común:** El nodo no tiene suficientes recursos o la imagen tarda en descargar.

**Solución:**

```bash
# Ver qué evento ocurrió
kubectl describe pod <nombre-del-pod>

# Verificar capacidad de recursos del nodo (sin necesidad de Metrics Server)
kubectl describe node minikube

# O ver el resumen de capacidad allocatable:
kubectl get nodes -o custom-columns=NAME:.metadata.name,CPU:.status.allocatable.cpu,MEMORY:.status.allocatable.memory

# Aumentar tamaño de Minikube si no tiene recursos suficientes
minikube stop
minikube start --cpus=4 --memory=4096
```

---

### Problema 2: Los eventos no muestran nada

**Síntoma:** `kubectl get events` muestra lista vacía.

**Causa común:** Los eventos expiran cada 1 hora. Si los Pods ya están `Running`, los eventos antiguos desaparecen.

**Solución:**

```bash
# Crear un Deployment nuevo para ver eventos frescos
kubectl delete deployment core-demo-quarkus
kubectl apply -f demo-deployment.yaml  # Esto genera eventos nuevos
```

---

### Problema 3: `kubectl exec` no funciona

**Síntoma:** Mensaje `command not found` o `connection refused`.

**Causa común:** El Pod no tiene bash o sh, o está en estado no listo.

**Solución:**

```bash
# Verificar que el Pod esté en Running
kubectl get pods

# Ver logs del contenedor
kubectl logs <pod-name>

# Usar shell predeterminada si bash no existe
kubectl exec -it <pod-name> -- /bin/sh
```

---

## Evidencia

Entrega las siguientes evidencias:

1. **Salida de Control Plane:**
   - Captura de `kubectl get pods -n kube-system` mostrando todos los componentes en `Running`
   - Captura de `kubectl get componentstatuses` mostrando todos en estado sano

2. **Eventos de Deployment:**
   - Captura de `kubectl get events --sort-by='.metadata.creationTimestamp'` mostrando la secuencia de creación

3. **Red plana validada:**
   - Captura de `kubectl get pods -o custom-columns=NAME:.metadata.name,IP:.status.podIP` mostrando IPs asignadas
   - Salida JSON del `curl` exitoso desde Pod 2 hacia Pod 1 por IP directa

4. **Jerarquía de objetos:**
   - Captura de `kubectl get deployment,replicaset,pods -l app=core-demo` mostrando la relación Deployment → ReplicaSet → Pods

---

## Continuidad

**Próximo paso:** El [Laboratorio 2.2](./laboratorio-clase-2-2.md) te enseñará a desplegar aplicaciones reales (inventory-service) con configuraciones de salud, estrategias de actualización y validar la autocuración del clúster.
