# Guía Rápida - Laboratorio Unidad 1
## Pasos de ejecución simplificados

Esta guía contiene los comandos esenciales para completar el laboratorio. Para detalles completos, consulta [laboratorio-1.md](../laboratorio-1.md).

---

## ✅ Pre-requisitos

Antes de comenzar, verifica que tienes:

- **Java 25** instalado
- **Docker Desktop** (incluye Docker Compose)
- **kubectl** (opcional, solo si usarás Kubernetes)

```bash
# Linux/Mac - Ejecuta el script de validación
./validar.sh

# Windows - Verifica manualmente en PowerShell
java -version  # Debe mostrar versión 25
docker --version
docker-compose --version
```

Si hay errores, consulta [WINDOWS.md](WINDOWS.md) para Windows o instala los componentes faltantes.

---

## 🚀 Opción 1: Ejecución Local (Desarrollo)

### Iniciar el servicio

```bash
cd catalog-service

# Linux/Mac
./mvnw quarkus:dev

# Windows (PowerShell o CMD)
mvnw.cmd quarkus:dev
```

### Probar endpoints

```bash
# En otra terminal
curl http://localhost:8080/v1/products
curl http://localhost:8080/v1/products/hello
curl http://localhost:8080/health/ready
```

### Generar carga para activar Circuit Breaker

```bash
# Genera 20 peticiones con medio segundo de pausa
for i in {1..20}; do 
  echo "Request $i:"
  curl -s http://localhost:8080/v1/products | jq '.status'
  sleep 0.5
done
```

Observarás:
- `🐳 Opción 2: Docker Compose (Recomendado para Windows)

### Iniciar con Docker Compose

```bash
# Desde el directorio proyecto-base/
docker-compose up -d

# Ver logs
docker-compose logs -f catalog-service

# Verificar estado
docker-compose ps

# Probar endpoints
curl http://localhost:8080/v1/products
curl http://localhost:8080/health

# Detener
docker-compose down
```

### Ventajas
- ✅ No requiere Kubernetes
- ✅ Funciona en Windows con Docker Desktop
- ✅ Fácil de iniciar y detener
- ✅ Ideal para desarrollo local

---

## ☸️ Opción 3: Despliegue en Kubernetes (Opcional)

**Solo si tienes acceso a Kubernetes (Docker Desktop K8s, Minikube, etc.)**

### Para Docker Desktop con Kubernetes habilitado
- `DEGRADED_CACHE` → Fallback activado por timeout o falla

---

## ☸️ Opción 2: Despliegue en Kubernetes (Minikube)

### Paso 1: Iniciar Minikube

```bash
# Iniciar cluster (si no está corriendo)
minikube start --cpus=2 --memory=4096

# Verificar estado
minikube status
```

### Paso 2: Construir la imagen en Minikube

```bash
cd catalog-service

# Apuntar Docker al daemon de Minikube
eval $(minikube docker-env)

# Compilar el proyecto
./mvnw clean package -DskipTests

# Construir imagen Docker
docker build -t catalog-service:1.0.0 .

# Verificar que la imagen esté disponible
docker images | grep catalog-service
```

### Paso 3: Desplegar en Kubernetes

```bash
# Aplicar Deployment (3 réplicas)
kubectl apply -f k8s/01-deployment.yaml

# Aplicar Service (LoadBalancer)
kubectl apply -f k8s/02-service.yaml

# Verificar pods
kubectl get pods -l app=catalog-service

# Esperar a que todos los pods estén RUNNING
kubectl wait --for=condition=ready pod -l app=catalog-service --timeout=90s
```

### Paso 4: Acceder al servicio

```bash
# Obtener la URL del servicio
minikube service catalog-service-lb --url

# O hacer port-forward
kubectl port-forward svc/catalog-service-lb 8080:80

# Probar (en otra terminal)
curl http://localhost:8080/v1/products
```

### Paso 5: Observar distribución y resiliencia

```bash
# Ver distribución de pods entre nodos
kubectl get pods -l app=catalog-service -o wide

# Ver logs de todos los pods
kubectl logs -l app=catalog-service --tail=20 -f

# Ver detalles del Deployment
kubectl describe deployment catalog-service-deployment

# Ver métricas del HPA (horizontal pod autoscaler)
kubectl get hpa
```

### Paso 6: Simular fallos

```bash
# Eliminar un pod (Kubernetes lo recreará automáticamente)
POD_NAME=$(kubectl get pods -l app=catalog-service -o jsonpath='{.items[0].metadata.name}')
kubectl delete pod $POD_NAME

# Observar la recuperación automática
kubectl get pods -l app=catalog-service -w
```

---

## 🧪 Pruebas de Estrés (Apache Bench)

### Instalar Apache Bench

```bash
# Ubuntu/Debian
sudo apt-get install apache2-utils

# macOS
brew install httpd
```

### Generar carga

```bash
# Obtener URL del servicio
SERVICE_URL=$(minikube service catalog-service-lb --url)

# Generar 1000 peticiones con 10 conexiones concurrentes
ab -n 1000 -c 10 $SERVICE_URL/v1/products

# O con curl en loop
for i in {1..100}; do
  curl -s $SERVICE_URL/v1/products &
done
wait
```

### Observar métricas

```bash
# Ver CPU y memoria de los pods
kubectl top pods -l app=catalog-service

# Ver eventos del cluster
kubectl get events --sort-by='.lastTimestamp'
```

---

## 📊 Comandos de Diagnóstico

### Ver configuración completa de un pod

```bash
kubectl get pod <POD_NAME> -o yaml
```

### Ver logs con timestamps

```bash
kubectl logs <POD_NAME> --timestamps
```

### Ejecutar shell dentro de un pod

```bash
kubectl exec -it <POD_NAME> -- /bin/sh

# Dentro del pod
curl localhost:8080/health
exit
```

### Ver endpoints del Service

```bash
kubectl get endpoints catalog-service-lb
```

### Ver configuración del Deployment

```bash
kubectl get deployment catalog-service-deployment -o yaml
```

---

## 🔧 Troubleshooting Rápido

### Problema: ImagePullBackOff

```bash
# Verificar que la imagen existe en Minikube
eval $(minikube docker-env)
docker images | grep catalog-service

# Si no existe, reconstruir
./mvnw clean package -DskipTests
docker build -t catalog-service:1.0.0 .
```

### Problema: Pods no inician (CrashLoopBackOff)

```bash
# Ver logs del pod
kubectl logs <POD_NAME>

# Ver eventos
kubectl describe pod <POD_NAME>
```

### Problema: Service no responde

```bash
# Verificar endpoints
kubectl get endpoints catalog-service-lb

# Si no hay endpoints, el selector no coincide
kubectl get pods --show-labels
kubectl get svc catalog-service-lb -o yaml | grep selector
```

### Problema: Health checks fallan

```bash
# Verificar readiness probe desde dentro del pod
kubectl exec -it <POD_NAME> -- curl localhost:8080/health/ready

# Incrementar initialDelaySeconds si el servicio tarda en iniciar
kubectl edit deployment catalog-service-deployment
```

---

## 🧹 Limpieza

### Eliminar recursos de Kubernetes

```bash
kubectl delete -f k8s/02-service.yaml
kubectl delete -f k8s/01-deployment.yaml

# Verificar que todo se eliminó
kubectl get all -l app=catalog-service
```

### Detener Minikube (opcional)

```bash
minikube stop
```

---

## 📖 Siguiente Paso

Una vez completado este laboratorio:

1. ✅ Crea el diagrama de arquitectura según el Paso 1 del laboratorio
2. ✅ Documenta los resultados de las pruebas de resiliencia
3. ✅ Prepárate para la Unidad 2 donde agregarás `inventory-service`

---

## 💡 Tips

**Usar alias para comandos frecuentes:**

```bash
alias k=kubectl
alias kgp='kubectl get pods'
alias kgs='kubectl get svc'
alias kgd='kubectl get deployments'
alias kdp='kubectl describe pod'
alias kl='kubectl logs'
```

**Ver todos los recursos de catalog-service:**

```bash
kubectl get all -l app=catalog-service
```

**Reiniciar todos los pods:**

```bash
kubectl rollout restart deployment catalog-service-deployment
```

---

**Material educativo - Instituto Tecnológico de Querétaro © 2026**
