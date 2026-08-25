#!/bin/bash

# Script de despliegue automatizado para catalog-service en Kubernetes
# Unidad 1 - Arquitecturas de alta disponibilidad y escalabilidad

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_header() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_info() {
    echo -e "${YELLOW}ℹ${NC} $1"
}

# Verificar que estamos en el directorio correcto
if [ ! -f "catalog-service/pom.xml" ]; then
    print_error "Este script debe ejecutarse desde el directorio proyecto-base/"
    exit 1
fi

print_header "Despliegue de Catalog Service - Unidad 1"

# Paso 1: Verificar Minikube
print_info "Verificando Minikube..."
if ! command -v minikube &> /dev/null; then
    print_error "Minikube no está instalado"
    exit 1
fi

if ! minikube status &> /dev/null; then
    print_warning "Minikube no está corriendo. Iniciando..."
    minikube start --cpus=2 --memory=4096
else
    print_success "Minikube está corriendo"
fi

# Paso 2: Apuntar Docker a Minikube
print_info "Configurando Docker para usar el daemon de Minikube..."
eval $(minikube docker-env)
print_success "Docker configurado"

# Paso 3: Compilar el proyecto
print_header "Compilando el proyecto"
cd catalog-service

print_info "Ejecutando: ./mvnw clean package -DskipTests"
if ./mvnw clean package -DskipTests; then
    print_success "Proyecto compilado exitosamente"
else
    print_error "Error al compilar el proyecto"
    exit 1
fi

# Paso 4: Construir imagen Docker
print_header "Construyendo imagen Docker"
print_info "Ejecutando: docker build -t catalog-service:1.0.0 ."
if docker build -t catalog-service:1.0.0 .; then
    print_success "Imagen Docker creada: catalog-service:1.0.0"
else
    print_error "Error al construir la imagen Docker"
    exit 1
fi

# Verificar que la imagen existe
if docker images | grep -q "catalog-service.*1.0.0"; then
    print_success "Imagen verificada en el registro local de Minikube"
else
    print_error "La imagen no se encuentra en el registro"
    exit 1
fi

# Paso 5: Desplegar en Kubernetes
print_header "Desplegando en Kubernetes"

# Eliminar recursos existentes si existen (para re-despliegues)
print_info "Limpiando recursos anteriores (si existen)..."
kubectl delete -f k8s/02-service.yaml --ignore-not-found=true
kubectl delete -f k8s/01-deployment.yaml --ignore-not-found=true
sleep 2

# Aplicar Deployment
print_info "Aplicando Deployment..."
if kubectl apply -f k8s/01-deployment.yaml; then
    print_success "Deployment creado"
else
    print_error "Error al crear el Deployment"
    exit 1
fi

# Aplicar Service
print_info "Aplicando Service..."
if kubectl apply -f k8s/02-service.yaml; then
    print_success "Service creado"
else
    print_error "Error al crear el Service"
    exit 1
fi

# Paso 6: Esperar a que los pods estén listos
print_header "Esperando a que los pods estén listos"
print_info "Este proceso puede tardar 30-60 segundos..."

if kubectl wait --for=condition=ready pod -l app=catalog-service --timeout=120s; then
    print_success "Todos los pods están listos"
else
    print_warning "Timeout esperando pods. Verificando estado..."
    kubectl get pods -l app=catalog-service
fi

# Paso 7: Mostrar estado del despliegue
print_header "Estado del Despliegue"

echo ""
echo "📦 Pods:"
kubectl get pods -l app=catalog-service -o wide

echo ""
echo "🔧 Deployment:"
kubectl get deployment catalog-service-deployment

echo ""
echo "🌐 Service:"
kubectl get service catalog-service-lb

echo ""
echo "📊 Endpoints:"
kubectl get endpoints catalog-service-lb

# Paso 8: Obtener URL del servicio
print_header "Acceso al Servicio"

SERVICE_URL=$(minikube service catalog-service-lb --url 2>/dev/null)

if [ -n "$SERVICE_URL" ]; then
    print_success "Servicio accesible en: $SERVICE_URL"
    echo ""
    echo "Puedes probar el servicio con:"
    echo "  curl $SERVICE_URL/v1/products"
    echo "  curl $SERVICE_URL/v1/products/hello"
    echo "  curl $SERVICE_URL/health"
    echo ""
    
    # Probar el servicio automáticamente
    print_info "Probando el servicio..."
    sleep 3
    
    if curl -s -f "$SERVICE_URL/health" > /dev/null; then
        print_success "El servicio responde correctamente"
        echo ""
        echo "Respuesta del endpoint /v1/products/hello:"
        curl -s "$SERVICE_URL/v1/products/hello"
        echo ""
    else
        print_warning "El servicio aún no responde. Puede tardar unos segundos más."
    fi
else
    print_warning "No se pudo obtener la URL automáticamente"
    echo ""
    echo "Obtén la URL manualmente con:"
    echo "  minikube service catalog-service-lb --url"
    echo ""
    echo "O usa port-forward:"
    echo "  kubectl port-forward svc/catalog-service-lb 8080:80"
fi

# Paso 9: Comandos útiles
print_header "Comandos Útiles"

cat << 'EOF'
# Ver logs de todos los pods
kubectl logs -l app=catalog-service --tail=50 -f

# Ver logs de un pod específico
kubectl logs <POD_NAME> -f

# Ejecutar shell en un pod
kubectl exec -it <POD_NAME> -- /bin/sh

# Generar carga para probar Circuit Breaker
for i in {1..20}; do curl -s $SERVICE_URL/v1/products | jq '.status'; sleep 0.5; done

# Simular fallo de pod (Kubernetes lo recreará)
kubectl delete pod <POD_NAME>

# Ver eventos del cluster
kubectl get events --sort-by='.lastTimestamp'

# Eliminar todo
kubectl delete -f k8s/
EOF

echo ""
print_header "¡Despliegue Completado!"

print_success "catalog-service está corriendo en Kubernetes"
echo ""
echo "Para ver el estado en tiempo real:"
echo "  watch kubectl get pods -l app=catalog-service"
echo ""
echo "Para eliminar el despliegue:"
echo "  kubectl delete -f k8s/"
echo ""
