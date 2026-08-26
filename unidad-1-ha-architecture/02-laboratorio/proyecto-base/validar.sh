#!/bin/bash

# Script de validación rápida para el proyecto base de la Unidad 1
# Este script verifica que todos los componentes estén correctamente configurados

set -e

echo "=========================================="
echo "  Validación del Proyecto - Unidad 1"
echo "=========================================="
echo ""

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Función para imprimir mensajes
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

# Contador de errores
ERRORS=0

echo "1. Verificando prerrequisitos..."
echo "-----------------------------------"

# Verificar Java
if command -v java &> /dev/null; then
    JAVA_VERSION=$(java -version 2>&1 | grep version | awk -F '"' '{print $2}' | awk -F '.' '{print $1}')
    if [ "$JAVA_VERSION" -ge 25 ]; then
        print_success "Java $JAVA_VERSION instalado"
    else
        print_error "Java 25+ requerido, encontrado: $JAVA_VERSION"
        ERRORS=$((ERRORS + 1))
    fi
else
    print_error "Java no encontrado"
    ERRORS=$((ERRORS + 1))
fi

# Verificar Maven (opcional)
if command -v mvn &> /dev/null; then
    MVN_VERSION=$(mvn -version | head -n 1 | awk '{print $3}')
    print_success "Maven $MVN_VERSION instalado"
else
    print_warning "Maven no encontrado (se usará Maven Wrapper)"
fi

# Verificar Docker
if command -v docker &> /dev/null; then
    DOCKER_VERSION=$(docker --version | awk '{print $3}' | sed 's/,//')
    print_success "Docker $DOCKER_VERSION instalado"
else
    print_error "Docker no encontrado"
    ERRORS=$((ERRORS + 1))
fi

# Verificar Docker Compose
if command -v docker-compose &> /dev/null; then
    COMPOSE_VERSION=$(docker-compose --version | awk '{print $4}' | sed 's/,//')
    print_success "Docker Compose $COMPOSE_VERSION instalado"
elif docker compose version &> /dev/null; then
    COMPOSE_VERSION=$(docker compose version --short)
    print_success "Docker Compose $COMPOSE_VERSION instalado (plugin)"
else
    print_warning "Docker Compose no encontrado (opcional pero recomendado)"
fi

# Verificar kubectl
if command -v kubectl &> /dev/null; then
    KUBECTL_VERSION=$(kubectl version --client --short 2>/dev/null | awk '{print $3}')
    print_success "kubectl $KUBECTL_VERSION instalado"
else
    print_warning "kubectl no encontrado (opcional - solo necesario para Kubernetes)"
fi

# Verificar Minikube o Docker Desktop K8s
if command -v minikube &> /dev/null; then
    MINIKUBE_VERSION=$(minikube version --short)
    print_success "Minikube $MINIKUBE_VERSION instalado"
elif kubectl cluster-info &> /dev/null; then
    print_success "Kubernetes detectado (Docker Desktop o cluster remoto)"
else
    print_warning "Kubernetes no detectado (opcional - puedes usar Docker Compose)"
fi

echo ""
echo "2. Verificando estructura del proyecto..."
echo "-----------------------------------"

cd "$(dirname "$0")/catalog-service" || exit 1

# Verificar archivos esenciales
FILES=(
    "pom.xml"
    "Dockerfile"
    "src/main/java/com/ecom/catalog/CatalogResource.java"
    "src/main/java/com/ecom/catalog/ReadinessHealthCheck.java"
    "src/main/resources/application.properties"
    "k8s/01-deployment.yaml"
    "k8s/02-service.yaml"
)

for file in "${FILES[@]}"; do
    if [ -f "$file" ]; then
        print_success "$file existe"
    else
        print_error "$file no encontrado"
        ERRORS=$((ERRORS + 1))
    fi
done

echo ""
echo "3. Validando configuración de Maven..."
echo "-----------------------------------"

# Verificar que el POM tenga las dependencias necesarias
if grep -q "quarkus-rest-jackson" pom.xml; then
    print_success "Dependencia quarkus-rest-jackson configurada"
else
    print_error "Falta dependencia quarkus-rest-jackson"
    ERRORS=$((ERRORS + 1))
fi

if grep -q "quarkus-smallrye-health" pom.xml; then
    print_success "Dependencia quarkus-smallrye-health configurada"
else
    print_error "Falta dependencia quarkus-smallrye-health"
    ERRORS=$((ERRORS + 1))
fi

if grep -q "quarkus-smallrye-fault-tolerance" pom.xml; then
    print_success "Dependencia quarkus-smallrye-fault-tolerance configurada"
else
    print_error "Falta dependencia quarkus-smallrye-fault-tolerance"
    ERRORS=$((ERRORS + 1))
fi
if grep -q "<quarkus.platform.version>3.38.0</quarkus.platform.version>" pom.xml; then
    print_success "Quarkus versión 3.38.0 configurada"
else
    print_warning "Versión de Quarkus diferente a 3.38.0"
fi

echo ""
echo "4. Validando código fuente..."
echo "-----------------------------------"

# El starter comienza sin estos patrones; el alumno los implementará en clase.
for pattern in "@CircuitBreaker" "@Retry" "@Timeout" "@Fallback"; do
    if grep -q "$pattern" src/main/java/com/ecom/catalog/CatalogResource.java; then
        print_success "$pattern implementado"
    else
        print_info "$pattern pendiente: corresponde al ejercicio de resiliencia"
    fi
done

# Verificar Health Check
if grep -q "@Readiness" src/main/java/com/ecom/catalog/ReadinessHealthCheck.java; then
    print_success "Readiness Health Check configurado"
else
    print_error "Readiness Health Check no encontrado"
    ERRORS=$((ERRORS + 1))
fi

echo ""
echo "5. Validando manifiestos de Kubernetes..."
echo "-----------------------------------"

# Verificar replicas en Deployment
if grep -q "replicas: 3" k8s/01-deployment.yaml; then
    print_success "Deployment configurado con 3 réplicas"
else
    print_warning "Deployment no tiene 3 réplicas"
fi

# Verificar topologySpreadConstraints
if grep -q "topologySpreadConstraints" k8s/01-deployment.yaml; then
    print_success "Topology Spread Constraints configurado"
else
    print_error "Topology Spread Constraints no encontrado"
    ERRORS=$((ERRORS + 1))
fi

# Verificar probes
if grep -q "readinessProbe" k8s/01-deployment.yaml; then
    print_success "Readiness Probe configurado"
else
    print_error "Readiness Probe no encontrado"
    ERRORS=$((ERRORS + 1))
fi

if grep -q "livenessProbe" k8s/01-deployment.yaml; then
    print_success "Liveness Probe configurado"
else
    print_error "Liveness Probe no encontrado"
    ERRORS=$((ERRORS + 1))
fi

# Verificar Service tipo LoadBalancer
if grep -q "type: LoadBalancer" k8s/02-service.yaml; then
    print_success "Service tipo LoadBalancer configurado"
else
    print_error "Service no es tipo LoadBalancer"
    ERRORS=$((ERRORS + 1))
fi

echo ""
echo "6. Compilación del proyecto..."
echo "-----------------------------------"

print_info "Ejecutando: mvn clean verify -DskipTests"

if ./mvnw clean verify -DskipTests > /dev/null 2>&1; then
    print_success "Proyecto compila correctamente"
else
    print_error "Error al compilar el proyecto"
    print_info "Ejecuta: ./mvnw clean verify para ver detalles"
    ERRORS=$((ERRORS + 1))
fi

echo ""
echo "=========================================="
echo "  Resumen de Validación"
echo "=========================================="
echo ""

if [ $ERRORS -eq 0 ]; then
    print_success "¡Validación completada exitosamente!"
    echo ""
    echo "El proyecto está listo para:"
    echo "  1. Ejecutar en modo desarrollo: ./mvnw quarkus:dev"
    echo "  2. Ejecutar con Docker Compose: docker-compose up -d"
    echo "  3. Construir imagen Docker: docker build -t catalog-service:1.0.0 ."
    echo "  4. Desplegar en Kubernetes (opcional): kubectl apply -f k8s/"
    echo ""
    echo "💡 Recomendado para Windows: usar Docker Compose (opción 2)"
    echo ""
    exit 0
else
    print_error "Se encontraron $ERRORS error(es)"
    echo ""
    echo "Por favor, revisa los errores antes de continuar."
    echo ""
    exit 1
fi
