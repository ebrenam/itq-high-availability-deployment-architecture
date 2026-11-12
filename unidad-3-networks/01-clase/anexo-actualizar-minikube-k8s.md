# Prerequisitos: Kubernetes 1.32.0 compatible con Kong Gateway

## ¿Por qué K8s 1.32.0?

**Laboratorio 3.1** usa **Kong Gateway v3.9.1** como controlador de Gateway API.

- ✅ K8s 1.32.0: Compatible con Kong v3.9.1, sin problemas de compatibilidad
- ✅ Kong es estable, maduro y usado en producción
- ✅ Instalación simple y confiable via Helm

## Actualizar Minikube

### Opción 1: Actualizar existente (recomendado)

Si ya tienes minikube en K8s 1.28 o 1.31, actualízalo:

```bash
# Detén minikube
minikube stop

# Inicia con Kubernetes 1.32.0
minikube start --kubernetes-version=1.32.0 --cpus=4 --memory=4096

# Verifica versión
kubectl version
```

**Resultado esperado:**
```
Server Version: v1.32.0
```

### Opción 2: Recrear desde cero (más limpio)

Si prefieres comenzar de cero:

```bash
# Elimina minikube completamente
minikube delete

# Recrea con K8s 1.32.0
minikube start --kubernetes-version=1.32.0 --cpus=4 --memory=4096

# Verifica
kubectl version
```

## Warnings esperados (NO son errores)

Durante la actualización, puede ver:

### Warning 1: Docker disk space
```
🧯  Docker is nearly out of disk space, which may cause deployments to fail! (96% of capacity).
```

**Solución (opcional, solo si hay problemas):**
```bash
docker system prune -a
```

### Warning 2: kubectl client version mismatch
```
❗  /snap/bin/kubectl is version 1.35.10, which may have incompatibilities with Kubernetes 1.32.0.
```

**Esto es NORMAL.** kubectl 1.35.10 es compatible hacia atrás con K8s 1.32.0 (versiones diferentes pero compatibles). No necesita acción.

### Warning 3: Cached images no encontradas
```
❌  Unable to load cached images: LoadCachedImages: stat ...
```

**Esto es NORMAL.** Se reconstruyen automáticamente. No necesita acción.

## Verificar instalación

```bash
# Confirma K8s 1.32.0
kubectl version

# Verifica que minikube está corriendo
minikube status

# Comprueba pods de sistema
kubectl get pods -n kube-system
```

## Tiempo estimado

- **Opción 1 (actualizar existente):** 5-10 minutos
- **Opción 2 (recrear):** 10-15 minutos
