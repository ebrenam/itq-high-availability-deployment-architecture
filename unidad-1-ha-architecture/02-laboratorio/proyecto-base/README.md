# Proyecto Base - Unidad 1
## Arquitecturas de alta disponibilidad y escalabilidad

Este directorio contiene el **código base funcional** para el laboratorio integrador de la Unidad 1.

## 📦 Contenido

```text
proyecto-base/
└── catalog-service/          # Servicio de catálogo con patrones de resiliencia
    ├── src/                  # Código fuente Java/Quarkus
    ├── k8s/                  # Manifiestos de Kubernetes
    ├── pom.xml               # Configuración Maven
    ├── Dockerfile            # Imagen Docker multi-stage
    └── README.md             # Documentación del servicio
```

## 🎯 Objetivo de la Unidad

Construir, desplegar y validar una arquitectura resiliente en **Quarkus** sobre un clúster local de **Kubernetes** con simulación de topología multi-AZ. Implementar patrones de resiliencia en capa de aplicación (circuit breaker, timeout, fallback, health checks) y en capa de infraestructura (topology spread constraints, readiness/liveness probes).

## 🛠️ Tecnologías y Versiones

| Componente | Versión | Descripción |
|-----------|---------|-------------|
| Java | OpenJDK 25 | Lenguaje de programación |
| Quarkus | 3.33.0 LTS | Framework cloud-native |
| Maven | 3.9.6 | Herramienta de build |
| Docker Desktop | 24.0+ | Container runtime (incluye Docker Compose) |
| Kubernetes | 1.28+ | Orquestador (OPCIONAL) |
| Docker Compose | 2.x | Alternativa a Kubernetes para desarrollo local |

## 🚀 Inicio Rápido

### Paso 1: Verificar prerrequisitos

```bash
# Verificar Java
java -version
# Debe mostrar: openjdk version "25"

# Verificar Maven (opcional, el proyecto incluye Maven Wrapper)
mvn -version

# Verificar Docker Desktop
docker --version
docker-compose --version

# Verificar Kubernetes (OPCIONAL - solo si lo usarás)
kubectl version --client
# En Windows: Habilitar K8s en Docker Desktop → Settings → Kubernetes
```

### Paso 2: Ejecutar en modo desarrollo

```bash
cd catalog-service

# Opción A: Con Maven Wrapper (recomendado)
./mvnw quarkus:dev

# Opción B: Con Maven instalado
mvn quarkus:dev
```

El servicio estará disponible en http://localhost:8080

### Paso 3: Probar el servicio

```bash
# Endpoint principal con patrones de resiliencia
curl http://localhost:8080/v1/products

# Health checks
curl http://localhost:8080/ready
curl http://localhost:8080/live
```

a: Ejecutar con Docker Compose (Recomendado - No requiere K8s)

**Ideal para Windows con Docker Desktop:**

```bash
# Desde el directorio proyecto-base/
docker-compose up -d

# Ver logs
docker-compose logs -f catalog-service

# Probar el servicio
curl http://localhost:8080/v1/products
curl http://localhost:8080/health

# Detener
docker-compose down
```

### Paso 4b: Desplegar en Kubernetes (Opcional)

**Solo si tienes acceso a un cluster Kubernetes:**

Consulta el [README.md del servicio](catalog-service/README.md) para instrucciones detalladas.

**Resumen rápido para Docker Desktop Kubernetes:**

```bash
cd catalog-service

# Compilar y construir imagen
./mvnw clean package -DskipTests
docker build -t catalog-service:1.0.0 .

# Desplegar en Kubernetes (si está habilitado en Docker Desktop)
kubectl apply -f k8s/01-deployment.yaml
kubectl apply -f k8s/02-service.yaml

# Verificar
kubectl get pods -l app=catalog-service
kubectl get svc catalog-service-lb
minikube service catalog-service-lb --url
```

## 📚 Relación con el Laboratorio

Este código base es **100% funcional** y está alineado con [laboratorio-1.md](../laboratorio-1.md).

**El alumno trabajará con este código para:**

1. ✅ Ejecutarlo localmente y comprender el funcionamiento
2. ✅ Construir la imagen Docker
3. ✅ Desplegarlo en Kubernetes
4. ✅ Validar los patrones de resiliencia (Circuit Breaker, Retry, Timeout, Fallback)
5. ✅ Observar la distribución multi-AZ con topology spread constraints
6. ✅ Simular fallos y verificar la recuperación automática
7. ✅ Generar el diagrama de arquitectura del sistema desplegado

**El código ya incluye:**

- ✅ Patrones de tolerancia a fallos completamente funcionales
- ✅ Health checks para Kubernetes
- ✅ Configuración de topología multi-AZ
- ✅ Readiness y Liveness probes
- ✅ Recursos y límites computacionales
- ✅ Security context para hardening
- ✅ Documentación completa

## 🔍 Validación Rápida

Para verificar que todo funciona correctamente:

```bash
# 1. Compilar el proyecto
cd catalog-service
./mvnw clean verify

# 2. Ejecutar en dev mode
./mvnw quarkus:dev
# Presiona Ctrl+C para detener

# 3. Validar Docker build
docker build -t catalog-service:test .

# 4. Validar manifiestos de Kubernetes
kubectl apply --dry-run=client -f k8s/
```

## 📖 Estructura del Código

### CatalogResource.java

Endpoint REST principal que implementa:
- `@Timeout(800)`: Timeout de 800ms
- `@Retry(maxRetries = 2, delay = 150)`: 2 reintentos con 150ms de pausa
- `@CircuitBreaker(...)`: Se abre si falla el 50% de las últimas 4 peticiones
- `@Fallback(fallbackMethod = "getCatalogFallback")`: Método de respaldo

### ReadinessHealthCheck.java

Health check personalizado que simula validación de conectividad a base de datos con 95% de disponibilidad.

### Deployment (01-deployment.yaml)

- 3 réplicas para alta disponibilidad
- Topology spread constraints para distribución multi-AZ
- Startup, Liveness y Readiness probes
- Límites de recursos (CPU: 200m-500m, Memory: 256Mi-512Mi)
- Security context no-root

### Service (02-service.yaml)

LoadBalancer que expone el puerto 80 y mapea al 8080 del contenedor.

## 🎓 Actividades del Laboratorio

El alumno deberá completar las siguientes actividades según [laboratorio-1.md](../laboratorio-1.md):

1. **Paso 1**: Mapeo de la arquitectura de resiliencia (diagrama)
2. **Paso 2**: Creación e instrumentación del microservicio (código ya provisto)
3. **Paso 3**: Simulación de topología multi-AZ (manifiestos ya provistos)
4. **Paso 4**: Despliegue en Kubernetes con validación de resiliencia
5. **Paso 5**: Pruebas de estrés y validación del Circuit Breaker
6. **Paso 6**: Análisis de logs y comportamiento bajo fallo

## 🐛 Troubleshooting Común

### Maven Wrapper no funciona

```bash
# Dar permisos de ejecución
chmod +x mvnw

# O usar Maven instalado directamente
mvn quarkus:dev
```

### Error "ImagePullBackOff" en Kubernetes

```bash
# Asegúrate de construir la imagen en el contexto de Minikube
eval $(minikube docker-env)
docker build -t catalog-service:1.0.0 .
```

### Pods no se distribuyen en múltiples zonas

```bash
# Minikube por defecto solo tiene 1 nodo
# Para simular multi-AZ, etiqueta el nodo:
kubectl label nodes minikube topology.kubernetes.io/zone=zone-a
```

## 📞 Soporte

Para dudas o problemas:

1. Consulta el [README.md del servicio](catalog-service/README.md)
2. Revisa el [laboratorio-1.md](../laboratorio-1.md)
3. Contacta al instructor

## ⏭️ Siguiente Unidad

Al finalizar esta unidad, el resultado funcional servirá como base para la **Unidad 2**, donde se agregará `inventory-service` y se externalizarán configuraciones con ConfigMaps y Secrets.

---

**Material educativo - Instituto Tecnológico de Querétaro © 2026**
