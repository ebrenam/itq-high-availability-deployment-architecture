# Laboratorio de la clase 1.3: Despliegue y autocuración

## Objetivo

Empaquetar el `catalog-service` resiliente del laboratorio 1.2 y desplegarlo con Kubernetes. Se validarán réplicas, probes, distribución topológica y recuperación automática.

## Punto de partida

Trabaja desde `02-laboratorio/proyecto-base/catalog-service` con los patrones implementados por el alumno en `CatalogResource.java`. No crees un `Deployment` ni un `Service` alternativo.

## Paso 1: Construir la imagen

```bash
cd Unidad-1-ha-architecture/02-laboratorio/proyecto-base/catalog-service
./mvnw clean package -DskipTests
docker build -t catalog-service:1.0.0 .
```

Si usas Minikube, carga la imagen en su entorno:

```bash
minikube image load catalog-service:1.0.0
```

## Paso 2: Preparar la topología

Para observar distribución entre zonas necesitas al menos dos nodos. En un clúster de un solo nodo solo podrás validar el manifiesto, las réplicas y la autocuración, no una multi-AZ real.

Consulta los nodos:

```bash
kubectl get nodes --show-labels
```

En un clúster local multi-nodo, etiqueta los nodos con zonas distintas:

```bash
kubectl label node <nodo-a> topology.kubernetes.io/zone=zone-a --overwrite
kubectl label node <nodo-b> topology.kubernetes.io/zone=zone-b --overwrite
```

## Paso 3: Revisar y aplicar los manifiestos

Revisa `k8s/01-deployment.yaml` y `k8s/02-service.yaml`. Confirma que usan `app: catalog-service`, tres réplicas, imagen local y las rutas `/health/live` y `/health/ready`.

Aplica los recursos:

```bash
kubectl apply -f k8s/01-deployment.yaml
kubectl apply -f k8s/02-service.yaml
kubectl wait --for=condition=available deployment/catalog-service-deployment --timeout=120s
```

## Paso 4: Validar réplicas, salud y distribución

```bash
kubectl get deployment catalog-service-deployment
kubectl get pods -l app=catalog-service -o wide
kubectl get endpoints catalog-service-lb
```

Relaciona cada Pod con su nodo y zona:

```bash
kubectl get pods -l app=catalog-service -o custom-columns='POD:.metadata.name,NODE:.spec.nodeName,READY:.status.containerStatuses[0].ready,PHASE:.status.phase'
```

Si dispones de dos o más nodos, comprueba que las réplicas se distribuyeron entre ellos. Si solo existe un nodo, documenta la limitación: `topologySpreadConstraints` no puede crear zonas que el clúster no tiene.

## Paso 5: Validar el servicio y la resiliencia

Obtén acceso al servicio. Con Minikube:

```bash
SERVICE_URL=$(minikube service catalog-service-lb --url)
curl -s "$SERVICE_URL/v1/products"
```

O usa _port-forward_:

```bash
kubectl port-forward svc/catalog-service-lb 8080:80
curl -s http://localhost:8080/v1/products
```

Genera tráfico y verifica que aparecen respuestas `SUCCESS` y `DEGRADED_CACHE` según la implementación del laboratorio 1.2:

```bash
for i in {1..50}; do
    curl -sS "$SERVICE_URL/v1/products"
    echo
done
```

## Paso 6: Simular la caída de una réplica

En otra terminal elimina un Pod y observa el reemplazo:

```bash
TARGET_POD=$(kubectl get pods -l app=catalog-service -o jsonpath='{.items[0].metadata.name}')
kubectl delete pod "$TARGET_POD"
kubectl get pods -l app=catalog-service -w
```

El `Deployment` debe crear un nuevo Pod para regresar al estado deseado de tres réplicas. Conserva la salida anterior y posterior como evidencia.

## Evidencia

Entrega:

- Imagen construida y salida de compilación.
- Estado de Deployment, Pods, Service y Endpoints.
- Distribución por nodo y zona, indicando si el clúster tenía suficientes nodos.
- Respuestas normales y degradadas del servicio.
- Evidencia de eliminación y recreación de un Pod.
- Explicación de qué resuelve la aplicación (`Fallback`) y qué resuelve Kubernetes (réplicas, probes y autocuración).

## Continuidad

Este resultado es el insumo técnico del laboratorio integrador `laboratorio-1.md`. Allí se consolidan las evidencias y se evalúa el comportamiento completo.
