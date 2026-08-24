# Catalog Service - Unidad 1

**Servicio de catálogo** para la plataforma e-commerce - Parte del proyecto integrador de la asignatura **Arquitectura de despliegue de alta disponibilidad**.

## 📋 Descripción

Este microservicio implementa el catálogo de productos con patrones de resiliencia y alta disponibilidad:

- ✅ **Circuit Breaker**: Protege contra fallos en cascada
- ✅ **Retry**: Reintenta operaciones fallidas
- ✅ **Timeout**: Previene esperas indefinidas
- ✅ **Fallback**: Sirve datos degradados cuando el servicio principal falla
- ✅ **Health Checks**: Readiness y Liveness probes para Kubernetes

## 🛠️ Stack Tecnológico

- **Java**: OpenJDK 25
- **Framework**: Quarkus 3.33.0 LTS
- **Build Tool**: Maven 3.9.6
- **Container Runtime**: Docker/Podman
- **Orchestrator**: Kubernetes 1.28+ (opcional)
- **Alternativa**: Docker Compose

## 📁 Estructura del Proyecto

```
catalog-service/
├── pom.xml                           # Configuración de Maven y dependencias
├── Dockerfile                        # Imagen Docker multi-stage
├── src/
│   └── main/
│       ├── java/com/ecom/catalog/
│       │   ├── CatalogResource.java           # Endpoint REST con patrones de resiliencia
│       │   └── ReadinessHealthCheck.java      # Health check personalizado
│       └── resources/
│           └── application.properties         # Configuración de Quarkus
└── k8s/
    ├── 01-deployment.yaml            # Deployment con 3 réplicas y topología multi-AZ
    └── 02-service.yaml               # Service tipo LoadBalancer
```

## 🚀 Ejecución Local (Modo Desarrollo)

### Prerrequisitos

- Java 25+ instalado
- Maven 3.9+ instalado (o usar Maven Wrapper incluido)

### Comandos

```bash
# Modo desarrollo con hot reload
./mvnw quarkus:dev

# O si no tienes Maven wrapper
mvn quarkus:dev
```

El servicio estará disponible en:
- **API**: http://localhost:8080/v1/products
- **Health**: http://localhost:8080/health
- **Readiness**: http://localhost:8080/health/ready
- **Liveness**: http://localhost:8080/health/live

### Probar el endpoint

```bash
# Endpoint principal (con patrones de resiliencia)
curl http://localhost:8080/v1/products

# Endpoint simple de prueba
curl http://localhost:8080/v1/products/hello

# Health checks
curl http://localhost:8080/health
curl http://localhost:8080/health/ready
curl http://localhost:8080/health/live
```

## 🐳 Construcción de la Imagen Docker

### Opción 1: Con Docker

```bash
# Compilar y empaquetar
./mvnw clean package -DskipTests

# Construir imagen Docker
docker build -t catalog-service:1.0.0 .

# Ejecutar contenedor localmente
docker run -p 8080:8080 catalog-service:1.0.0
```

### Opción 2: Con Podman

```bash
# Compilar y empaquetar
./mvnw clean package -DskipTests

# Construir imagen con Podman
podman build -t catalog-service:1.0.0 .

# Ejecutar contenedor localmente
podman run -p 8080:8080 catalog-service:1.0.0
```

### Opción 3: Para Docker Desktop o Minikube

```bash
# Para Docker Desktop (imagen local)
./mvnw clean package -DskipTests
docker build -t catalog-service:1.0.0 .

# Para Minikube (apuntar al daemon de Minikube)
eval $(minikube docker-env)
./mvnw clean package -DskipTests
docker build -t catalog-service:1.0.0 .

# La imagen ahora está disponible localmente sin necesidad de registry
```

## 🐳 Opción 2: Ejecución con Docker Compose (Sin Kubernetes)

**Ideal para Windows con Docker Desktop o desarrollo local sin K8s.**

### Prerrequisitos

- Docker Desktop instalado (Windows/macOS/Linux)
- Docker Compose incluido

### Ejecutar con Docker Compose

```bash
# Desde el directorio proyecto-base/
cd ..

# Iniciar servicio
docker-compose up -d

# Ver logs
docker-compose logs -f catalog-service

# Verificar estado
docker-compose ps

# Probar el servicio
curl http://localhost:8080/v1/products
curl http://localhost:8080/health

# Detener servicio
docker-compose down
```

### Ventajas de Docker Compose

- ✅ No requiere Kubernetes
- ✅ Funciona en Windows con Docker Desktop
- ✅ Fácil de iniciar y detener
- ✅ Ideal para desarrollo local
- ✅ Simula microservicios interconectados

---

## ☸️ Opción 3: Despliegue en Kubernetes (Opcional)

**Solo si tienes acceso a un cluster Kubernetes.**

### Prerrequisitos

- Kubernetes 1.28+ (Docker Desktop K8s, Minikube, Kind, K3s o cluster remoto)
- kubectl configurado
- Imagen `catalog-service:1.0.0` disponible en el cluster

### Despliegue paso a paso

```bash
# 1. Aplicar el Deployment (3 réplicas con topología multi-AZ)
kubectl apply -f k8s/01-deployment.yaml

# 2. Aplicar el Service (LoadBalancer)
kubectl apply -f k8s/02-service.yaml

# 3. Verificar que los pods estén corriendo
kubectl get pods -l app=catalog-service

# 4. Verificar el Deployment
kubectl get deployment catalog-service-deployment

# 5. Verificar el Service y obtener la IP externa
kubectl get service catalog-service-lb

# 6. Ver logs de un pod específico
kubectl logs -l app=catalog-service --tail=50 -f
```

### Probar el servicio en Kubernetes

```bash
# Si usas Minikube, obtener la URL del servicio
minikube service catalog-service-lb --url

# Probar el endpoint
curl $(minikube service catalog-service-lb --url)/v1/products

# O hacer port-forward directo
kubectl port-forward svc/catalog-service-lb 8080:80
curl http://localhost:8080/v1/products
```

## 🧪 Validación de Patrones de Resiliencia

### Probar Circuit Breaker y Fallback

El servicio simula fallos aleatorios:
- 20% de probabilidad de latencia alta (>1200ms → timeout)
- 30% de probabilidad de falla de conexión a DB
- 50% de probabilidad de respuesta exitosa

```bash
# Generar múltiples peticiones para activar el circuit breaker
for i in {1..20}; do 
  curl -s http://localhost:8080/v1/products | jq '.status'
  sleep 0.5
done
```

**Observarás:**
- Respuestas `SUCCESS` cuando la petición es exitosa
- Respuestas `DEGRADED_CACHE` cuando se activa el fallback
- El circuit breaker se abre después de múltiples fallos consecutivos

### Verificar Health Checks

```bash
# Readiness probe (usado por Kubernetes para balanceo de carga)
curl http://localhost:8080/health/ready

# Liveness probe (usado por Kubernetes para reiniciar pods)
curl http://localhost:8080/health/live

# Health check completo
curl http://localhost:8080/health | jq
```

## 📊 Monitoreo (Preparación para Unidad 5)

El servicio ya incluye anotaciones para Prometheus:

```yaml
prometheus.io/scrape: "true"
prometheus.io/port: "8080"
prometheus.io/path: "/q/metrics"
```

En la Unidad 5 configurarás Prometheus para recolectar métricas automáticamente.

## 🔧 Troubleshooting

### Problema: Pods en estado `ImagePullBackOff`

**Causa**: Kubernetes no encuentra la imagen `catalog-service:1.0.0`

**Solución en Minikube**:
```bash
eval $(minikube docker-env)
docker build -t catalog-service:1.0.0 .
```

### Problema: Readiness probe falla constantemente

**Causa**: La aplicación tarda más en arrancar de lo esperado

**Solución**: Incrementar `initialDelaySeconds` en el Deployment:
```yaml
readinessProbe:
  initialDelaySeconds: 15  # aumentar de 5 a 15
```

### Problema: Pods en `CrashLoopBackOff`

**Causa**: Error en el código o configuración incorrecta

**Solución**: Ver logs del pod
```bash
kubectl logs <pod-name>
kubectl describe pod <pod-name>
```

## 📚 Próximos Pasos

Este servicio es la base para las siguientes unidades:

- **Unidad 2**: Agregar ConfigMaps, Secrets y Horizontal Pod Autoscaler (HPA)
- **Unidad 3**: Exponer con Ingress y aplicar NetworkPolicies
- **Unidad 4**: Implementar CI/CD con GitHub Actions y GitOps
- **Unidad 5**: Integrar observabilidad con Prometheus, Grafana y OpenTelemetry

## 🤝 Contribución

Este proyecto es parte del material educativo de la asignatura. Para sugerencias o mejoras, contacta al instructor.

## 📄 Licencia

Material educativo - Instituto Tecnológico de Querétaro © 2026
