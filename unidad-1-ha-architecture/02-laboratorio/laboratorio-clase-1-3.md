# Laboratorio de la clase 1.3: Despliegue y autocuración en Kubernetes

## Objetivo del laboratorio

Empaquetar el `catalog-service` resiliente del laboratorio 1.2 y desplegarlo en Kubernetes. Validarás réplicas, health checks, distribución topológica multi-AZ y recuperación automática (_self-healing_). Este laboratorio cierra el ciclo de la Unidad 1 consolidando resiliencia de software e infraestructura.

**Regla de continuidad:** Este laboratorio requiere que hayas completado exitosamente los laboratorios 1.1 y 1.2. Si comienzas aquí directamente, `CatalogResource.java` no tendrá los patrones de resiliencia (`@Timeout`, `@Retry`, `@CircuitBreaker`, `@Fallback`) y el despliegue no validará el impacto de esos patrones.

## Prerequisitos y stack tecnológico

Además de los prerequisitos de 1.1 y 1.2, necesitas:

- **Kubernetes local:** Minikube (v1.30+) o Kind (v0.20+) con v1.28+ instalado y configurado.
- **kubectl** configurado e interconectado con tu clúster local.
- **Docker** construido con la imagen `catalog-service:1.0.0` (o disponible para Minikube/Kind).
- **Conocimiento previo:** Manifiestos YAML básicos de Kubernetes (Deployment, Service, labels).

## Punto de partida

Trabaja desde `02-laboratorio/proyecto-base-unidad-01/catalog-service` con los patrones implementados por el alumno en `CatalogResource.java` (del laboratorio 1.2). No crees un `Deployment` ni un `Service` alternativo; usa los archivos existentes en `k8s/01-deployment.yaml` y `k8s/02-service.yaml`.

---

## Paso 0: Mapeo de la arquitectura de resiliencia

Antes de tirar líneas de `kubectl`, diseña visualmente el diagrama arquitectónico de la solución objetivo. Puede ser en papel, Draw.io, Lucidchart o Excalidraw.

Asegúrate de mapear:

1. **Punto de entrada de tráfico:** El _LoadBalancer Service_ que expone el puerto 80.
2. **Distribución de réplicas:** 3 pods del `catalog-service` distribuidos entre AZs (zonas de disponibilidad).
3. **Aislamiento de fallas:** Cómo los patrones _circuit breaker_ y _fallback_ protegen contra fallas de la base de datos.
4. **Health checks:** Las probes de Kubernetes (`startupProbe`, `livenessProbe`, `readinessProbe`) y cómo deciden si un pod está sano.
5. **Réplica de datos:** (Conceptualmente) Cómo los datos degradados del `DEGRADED_CACHE` permiten continuar el servicio.

**Guardaeste diagrama:** Lo necesitarás como evidencia en la entrega final.

---

## Paso 1: Construir la imagen Docker

Compila la aplicación y construye la imagen de contenedor:



```bash
cd Unidad-1-ha-architecture/02-laboratorio/proyecto-base-unidad-01/catalog-service
./mvnw clean package -DskipTests
docker build -t catalog-service:1.0.0 .
```

Si usas Minikube, carga la imagen en su entorno:

```bash
minikube image load catalog-service:1.0.0
```

---

## Paso 2: Confirmar requisitos previos del laboratorio 1.2

Antes de desplegar, valida que `CatalogResource.java` contiene los patrones de resiliencia. Desde `02-laboratorio/proyecto-base-unidad-01/catalog-service`:

**Verificación de patrones en código:**

```bash
grep -c "@Timeout" src/main/java/com/ecom/catalog/CatalogResource.java
grep -c "@Retry" src/main/java/com/ecom/catalog/CatalogResource.java
grep -c "@CircuitBreaker" src/main/java/com/ecom/catalog/CatalogResource.java
grep -c "@Fallback" src/main/java/com/ecom/catalog/CatalogResource.java
```

Debes obtener al menos un match en cada línea. Si alguno falta, vuelve al laboratorio 1.2 antes de continuar.

**Verificación de método fallback:**

```bash
grep -c "getCatalogFallback" src/main/java/com/ecom/catalog/CatalogResource.java
```

Debe retornar al menos 2 (definición del método y referencia en `@Fallback`).

---

## Paso 3: Preparar la topología

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

## Paso 4: Revisar y aplicar los manifiestos

Revisa `k8s/01-deployment.yaml` y `k8s/02-service.yaml`. Confirma que usan `app: catalog-service`, tres réplicas, imagen local y las rutas `/health/live` y `/health/ready`.

Aplica los recursos:

```bash
kubectl apply -f k8s/01-deployment.yaml
kubectl apply -f k8s/02-service.yaml
kubectl wait --for=condition=available deployment/catalog-service-deployment --timeout=120s
```

### Manifiestos Esperados Finales

Antes de aplicar, verifica que tus archivos coincidan con la siguiente estructura. Si tienes ajustes personalizados, mantén la semántica pero asegúrate de que los selectores y labels sean consistentes.

#### Archivo `k8s/01-deployment.yaml` (Completo)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: catalog-service-deployment
  labels:
    app: catalog-service
    version: v1.0.0
    tier: backend
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  selector:
    matchLabels:
      app: catalog-service
  template:
    metadata:
      labels:
        app: catalog-service
        version: v1.0.0
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "8080"
        prometheus.io/path: "/q/metrics"
    spec:
      topologySpreadConstraints:
        - maxSkew: 1
          topologyKey: topology.kubernetes.io/zone
          whenUnsatisfiable: ScheduleAnyway
          labelSelector:
            matchLabels:
              app: catalog-service
        - maxSkew: 1
          topologyKey: kubernetes.io/hostname
          whenUnsatisfiable: DoNotSchedule
          labelSelector:
            matchLabels:
              app: catalog-service
      containers:
        - name: catalog-service
          image: catalog-service:1.0.0
          imagePullPolicy: IfNotPresent
          ports:
            - name: http
              containerPort: 8080
              protocol: TCP
          env:
            - name: QUARKUS_LOG_LEVEL
              value: "INFO"
          resources:
            requests:
              cpu: "200m"
              memory: "256Mi"
            limits:
              cpu: "500m"
              memory: "512Mi"
          startupProbe:
            httpGet:
              path: /ready
              port: 8080
            initialDelaySeconds: 5
            periodSeconds: 3
            failureThreshold: 30
          livenessProbe:
            httpGet:
              path: /live
              port: 8080
            initialDelaySeconds: 10
            periodSeconds: 10
            timeoutSeconds: 3
            failureThreshold: 3
          readinessProbe:
            httpGet:
              path: /ready
              port: 8080
            initialDelaySeconds: 5
            periodSeconds: 5
            timeoutSeconds: 3
            failureThreshold: 2
          securityContext:
            runAsNonRoot: true
            runAsUser: 185
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: false
            capabilities:
              drop:
                - ALL
```

#### Archivo `k8s/02-service.yaml` (Completo)

```yaml
apiVersion: v1
kind: Service
metadata:
  name: catalog-service-lb
  labels:
    app: catalog-service
    tier: backend
  annotations:
    description: "LoadBalancer service for catalog-service - exposes HTTP endpoint"
spec:
  type: LoadBalancer
  selector:
    app: catalog-service
  ports:
    - name: http
      protocol: TCP
      port: 80
      targetPort: 8080
  sessionAffinity: None
  externalTrafficPolicy: Cluster
  internalTrafficPolicy: Cluster
```

**Puntos clave a verificar antes de aplicar:**

- ✅ `metadata.name` debe ser exactamente `catalog-service-deployment` en Deployment
- ✅ `spec.selector.matchLabels.app` debe ser `catalog-service`
- ✅ `template.metadata.labels.app` debe ser `catalog-service` (coincide con selector)
- ✅ `image` debe ser `catalog-service:1.0.0` (sin registry remoto para Minikube local)
- ✅ `imagePullPolicy` es `IfNotPresent` (usa imagen local)
- ✅ Las rutas de probes son `/ready`, `/live` (coinciden con `application.properties` de Quarkus)
- ✅ Service `metadata.name` es `catalog-service-lb` y su `selector` es `app: catalog-service`
- ✅ Service `port: 80` mapea a `targetPort: 8080` (entrada externa en 80, destino en 8080)

---

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

### Output Esperado (Clúster de 1 Nodo)

Cuando ejecutes los comandos de validación, deberías ver:

```
NAME                                     READY   UP-TO-DATE   AVAILABLE   AGE
catalog-service-deployment               3/3     3            3           45s

NAME                                 READY   STATUS    RESTARTS   AGE     IP            NODE
catalog-service-deployment-abc123-x1  1/1     Running   0          45s     10.244.0.10   minikube
catalog-service-deployment-abc123-x2  1/1     Running   0          43s     10.244.0.11   minikube
catalog-service-deployment-abc123-x3  1/1     Running   0          42s     10.244.0.12   minikube

NAME                     ENDPOINTS                                      AGE
catalog-service-lb       10.244.0.10:8080,10.244.0.11:8080,...        40s
```

**Verificación:**

- ✅ `READY 3/3`: Las 3 réplicas están en estado Ready
- ✅ `STATUS Running`: Todos los pods están en ejecución
- ✅ `ENDPOINTS` no está vacío: El Service encontró los pods (labels coinciden)
- ✅ `RESTARTS 0`: No hay reintentos automáticos de Kubernetes (aplicación sana)

### Output Esperado (Clúster Multi-nodo)

Si tienes múltiples nodos con etiquetas de zona, la distribución se verá así:

```
POD                                NODE        READY   PHASE
catalog-service-deployment-abc-x1   minikube    True    Running
catalog-service-deployment-abc-x2   minikube-m2 True    Running
catalog-service-deployment-abc-x3   minikube-m3 True    Running
```

Los pods están distribuidos entre nodos diferentes, cumpliendo las `topologySpreadConstraints`.

---

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

### Output Esperado en Paso 6

Cuando ejecutes el ciclo de 50 solicitudes, deberías ver intercaladas respuestas como:

```json
{"status":"SUCCESS","data":["Product A","Product B","Product C"]}
{"status":"SUCCESS","data":["Product A","Product B","Product C"]}
{"status":"DEGRADED_CACHE","data":["Cached Product A","Cached Product B"]}
{"status":"SUCCESS","data":["Product A","Product B","Product C"]}
{"status":"DEGRADED_CACHE","data":["Cached Product A","Cached Product B"]}
{"status":"DEGRADED_CACHE","data":["Cached Product A","Cached Product B"]}
{"status":"SUCCESS","data":["Product A","Product B","Product C"]}
...
```

**Verificación:**

- ✅ Respuestas `SUCCESS` con datos reales: El servicio alcanzó la base de datos exitosamente
- ✅ Respuestas `DEGRADED_CACHE`: El fallback se activó (Timeout, CircuitBreaker o falla de BD)
- ✅ **NO hay errores HTTP 500**: Los patrones de resiliencia evitaron el colapso
- ✅ Latencia variable pero consistentemente rápida: El Timeout cancela solicitudes lentas

Esto demuestra que la **resiliencia de software** (patrones en Java) está funcionando junto con la **orquestación** (3 réplicas en Kubernetes).

---

En otra terminal elimina un Pod y observa el reemplazo:

```bash
TARGET_POD=$(kubectl get pods -l app=catalog-service -o jsonpath='{.items[0].metadata.name}')
kubectl delete pod "$TARGET_POD"
kubectl get pods -l app=catalog-service -w
```

### Output Esperado en Paso 7 (Autocuración)

**ANTES de eliminar el pod:**

```
NAME                                 READY   STATUS    RESTARTS   AGE
catalog-service-deployment-abc123-x1  1/1     Running   0          120s
catalog-service-deployment-abc123-x2  1/1     Running   0          118s
catalog-service-deployment-abc123-x3  1/1     Running   0          116s
```

**Comando de eliminación:**

```bash
kubectl delete pod catalog-service-deployment-abc123-x1
```

**INMEDIATAMENTE DESPUÉS (en los siguientes 5-10 segundos):**

```
NAME                                 READY   STATUS        RESTARTS   AGE
catalog-service-deployment-abc123-x1  0/1     Terminating   0          120s
catalog-service-deployment-abc123-x2  1/1     Running       0          118s
catalog-service-deployment-abc123-x3  1/1     Running       0          116s
```

**DESPUÉS DE 15-30 SEGUNDOS (Autocuración completada):**

```
NAME                                 READY   STATUS    RESTARTS   AGE
catalog-service-deployment-abc123-x2  1/1     Running   0          118s
catalog-service-deployment-abc123-x3  1/1     Running   0          116s
catalog-service-deployment-abc123-x4  1/1     Running   0          8s
```

**Verificación:**

- ✅ El pod eliminado desapareció (x1)
- ✅ Los 2 pods restantes continuaron sirviendo tráfico (x2, x3)
- ✅ Kubernetes creó automáticamente un nuevo pod (x4) con un nombre diferente
- ✅ Después de ~30 segundos, el despliegue tiene nuevamente 3 réplicas en estado `Running`
- ✅ El servicio nunca se interrumpió: las 2 réplicas restantes absorbieron el tráfico

**Esto demuestra la capacidad de autocuración (_self-healing_) de Kubernetes.**

---

## Paso 8: Simulación de carga masiva y fallas de aplicación

Abre una terminal con los logs y, en otra, lanza tráfico masivo para forzar al _Circuit Breaker_ a actuar ante las fallas simuladas de la base de datos:

```bash
for i in {1..50}; do
    curl -sS -w ' | HTTP %{http_code} | tiempo %{time_total}s\n' "$SERVICE_URL/v1/products"
done | tee kubernetes-resilience-sample.txt
```

**Resultado esperado:** Verás que algunas peticiones devuelven `SUCCESS` y otras devuelven `DEGRADED_CACHE` sin ningún error HTTP `500`. El _Circuit Breaker_ abre el circuito y redirige las peticiones al método de _Fallback_ instantáneamente.

---

## Guía de Troubleshooting

### Problema 1: Los Pods se quedan en estado `CrashLoopBackOff` o `Error`

**Causa común:** La imagen Docker no está disponible dentro del contexto de ejecución de Kubernetes o el puerto configurado en el _probe_ no coincide con la aplicación.

**Diagnóstico técnico:**

```bash
# Revisa los eventos específicos del Pod dañado
kubectl describe pod <nombre-del-pod>

# Revisa los logs directos de la aplicación Java/Quarkus
kubectl logs <nombre-del-pod> --previous
```

**Solución:** Si estás en Minikube, asegúrate de ejecutar `minikube image load catalog-service:1.0.0` para que el clúster reconozca la imagen local sin intentar descargarla de Docker Hub.

### Problema 2: Los Pods están `Running` pero nunca entran en estado `READY 1/1`

**Causa común:** La ruta configurada en la `readinessProbe` (`/health/ready`) está mal escrita o la aplicación está tardando más tiempo del permitido por el parámetro `initialDelaySeconds` en responder.

**Diagnóstico técnico:**

```bash
kubectl get events --sort-by='.metadata.creationTimestamp'
```

Busca un mensaje que indique: `Readiness probe failed: HTTP probe failed with statuscode: 404`.

**Solución:** Verifica que la extensión `quarkus-smallrye-health` esté presente en el `pom.xml` e incrementa el parámetro `initialDelaySeconds` a `15` en el manifiesto YAML si es necesario.

### Problema 3: Las peticiones a través del `LoadBalancer Service` fallan con `Connection Refused`

**Causa común:** El _selector_ del _Service_ no coincide exactamente con las _labels_ definidas en el _template_ del _Deployment_.

**Diagnóstico técnico:**

```bash
# Verifica si el Service ha asociado IP internas de Pods como Endpoints
kubectl get endpoints catalog-service-lb
```

Si la columna `ENDPOINTS` aparece como `<none>`, las etiquetas no hacen _match_.

**Solución:** Corrige la sección `spec.selector` del _Service_ para que sea exactamente igual a `app: catalog-service`.

### Problema 4: La topología no distribuye entre zonas

**Causa común:** El clúster tiene un solo nodo o los nodos no tienen etiquetas de zona.

**Diagnóstico técnico:**

```bash
kubectl get nodes --show-labels | grep zone
```

Si no hay salida, las zonas no están etiquetadas.

**Solución:** En un clúster de un nodo (Minikube simple), esto es una limitación esperada. Documenta que la distribución topológica es una característica de clústeres multi-nodo.

---

## Criterios de aceptación / evidencia de entrega

Para considerar este laboratorio como **Aprobado**, el estudiante deberá entregar un reporte técnico individual en PDF con la siguiente estructura:

### 1. Diagrama de arquitectura
Exportación en imagen del diagrama creado en el Paso 0 mostrando:
- Punto de entrada (_LoadBalancer Service_)
- Distribución de réplicas entre AZs
- Patrones de resiliencia (_circuit breaker_, _fallback_)
- Health checks

### 2. Evidencia de construcción y despliegue
- Salida de compilación exitosa (`./mvnw clean package -DskipTests`)
- Salida de construcción de imagen Docker (`docker build ...`)
- Salida de aplicación de manifiestos (`kubectl apply ...`)

### 3. Evidencia de distribución y health
- Captura de pantalla de `kubectl get pods -l app=catalog-service -o wide` mostrando los 3 pods en estado `Running` y `READY 1/1`
- Captura de pantalla de `kubectl get pods -l app=catalog-service -o custom-columns=...` mostrando la distribución por nodo

### 4. Evidencia de autocuración por infraestructura
- Captura de pantalla de `kubectl get pods -l app=catalog-service -o wide` **ANTES** de eliminar un Pod
- Captura de pantalla de `kubectl delete pod $TARGET_POD` ejecutándose
- Captura de pantalla de `kubectl get pods -l app=catalog-service -w` mostrando el nuevo Pod generado automáticamente en estado `Running`

### 5. Evidencia de resiliencia por software (_Fallback_ activo)
- Captura del output en terminal de la ejecución del ciclo de peticiones en bash mostrando tanto:
  - Respuestas con código `SUCCESS`
  - Respuestas degradadas `DEGRADED_CACHE`
  - **SIN ningún error `500 Internal Server Error`**

### 6. Explicación técnica integrada
Un párrafo de máximo 150 palabras explicando:

- Cómo los patrones de resiliencia implementados en el código (`@Timeout`, `@Retry`, `@CircuitBreaker`, `@Fallback`) evitan errores `500` y mantienen la disponibilidad degradada.
- Cómo los mecanismos de Kubernetes (réplicas, health checks, `topologySpreadConstraints`) garantizan que la falla de un nodo o una zona de disponibilidad no interrumpe el servicio.
- Relación entre `MTTR` (_Mean Time to Repair_) y la autocuración automática de Kubernetes.

---

## Continuidad

El código y las evidencias que generes aquí consolidan el trabajo de los laboratorios 1.1, 1.2 y 1.3. Este conjunto demuestra la integración de patrones de resiliencia (software) con infraestructura cloud-native (Kubernetes) para lograr alta disponibilidad.
