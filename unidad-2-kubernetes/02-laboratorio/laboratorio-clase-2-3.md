# Laboratorio 2.3: Configuración Externa y Escalamiento Automático

## Objetivo

Externalizarás configuración e implementarás escalamiento automático en la plataforma e-commerce, demostrando competencia completa en orquestación Kubernetes con alta disponibilidad.

**Salida esperada:** inventory-service + catalog-service con ConfigMaps, Secrets e HPA funcionando.

---

## Escenario real

> **Contexto:** Tu `inventory-service` está funcionando en producción, pero el equipo necesita:
> 1. Cambiar configuraciones por entorno (dev/staging/prod) **sin recompilar imagen**
> 2. Almacenar credenciales de base de datos de forma segura
> 3. Escalar automáticamente cuando CPU aumente durante horas pico (Black Friday)
>
> **Tu tarea:** Externalizar config, inyectar variables, habilitar HPA y demostrar escalamiento automático bajo carga.

---

## Regla de continuidad

**Requisito previo:** Completa [Laboratorio 2.2](./laboratorio-clase-2-2.md) exitosamente

**Dependencia:** inventory-service funcional con 2 réplicas, health probes validadas

**Conexión con Clase 2.3:** Implementarás cada concepto enseñado (ConfigMap, Secret, HPA)

## Prerequisitos y stack tecnológico

### Requisitos comunes (Linux, macOS, Windows)

- **Minikube** v1.32+ (o **Kind** v0.20+)
- **kubectl** CLI instalado y configurado
- El `inventory-service` desplegado (del Laboratorio 2.2)
- Acceso desde el clúster al registro de imágenes para descargar **BusyBox**, usado como generador de carga

### Verificación

```bash
# Ejecuta estos comandos para confirmar
kubectl version --client && minikube version && java -version && mvn -version
```

### Iniciar Minikube

```bash
minikube start --cpus=4 --memory=4096
```

## Punto de partida

Asume que tienes el `inventory-service` ejecutándose desde Laboratorio 2.2:

```bash
kubectl get deployment inventory-service
```

---

## Punto de partida (herencia de Laboratorio 2.2)

### Qué heredas

| Componente          | Estado                             |
| ------------------- | ---------------------------------- |
| `catalog-service`   | v1.0.0 (de U1 Laboratorio 1.3)     |
| `inventory-service` | v1.0.0 (creado en Laboratorio 2.2) |
| Deployments         | Ambos con health probes            |
| Images              | Publicadas en Docker Hub           |
| Services            | ClusterIP configurados             |

### Qué crearás nuevo

| Artefacto                    | Propósito                             |
| ---------------------------- | ------------------------------------- |
| ConfigMap `inventory-config` | Datos de configuración (URLs, flags)  |
| Secret `inventory-secrets`   | Credenciales (contraseñas, API keys)  |
| HPA `inventory-hpa`          | Escalamiento automático basado en CPU |
| Metrics Server               | Recolección de métricas               |

---

## Paso 1: Crear ConfigMap y Secret para externalizar configuración

**Qué hace:** Separar configuración y credenciales del código empaquetado en imagen Docker

**Por qué:** Permite usar la misma imagen en dev/staging/prod con diferentes configuraciones, sin recompilar

Crea `k8s/config-secrets.yaml`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: inventory-config
  labels:
    app: inventory-service
data:
  APP_ENVIRONMENT: "production-k8s"
  INVENTORY_DB_HOST: "db.acme.local"
  LOG_LEVEL: "INFO"
---
apiVersion: v1
kind: Secret
metadata:
  name: inventory-secrets
  labels:
    app: inventory-service
type: Opaque
stringData:
  # stringData convierte a base64 automáticamente
  DB_PASSWORD: "ProdSecure2026!"
  API_KEY_EXTERNAL: "sk_live_abc123def456"
```

### ![linux](images/linux.png) Linux/macOS

```bash
kubectl apply -f k8s/config-secrets.yaml

# Verificar
kubectl get configmap inventory-config
kubectl get secret inventory-secrets
```

### ![win](images/windows.png) Windows

```powershell
kubectl apply -f k8s/config-secrets.yaml

kubectl get configmap inventory-config
kubectl get secret inventory-secrets
```

### Qué observar

```bash
NAME                 DATA   AGE
inventory-config     3      2s

NAME                  TYPE     DATA   AGE
inventory-secrets     Opaque   2      2s
```

### Nota pedagógica

> **NOTA PEDAGÓGICA**
>
> Recuerda de Clase 2.3:
> - **ConfigMap:** Datos públicos, no confidenciales (URLs, flags, niveles de log)
> - **Secret:** Datos sensibles (contraseñas, API keys) - base64 NO es encriptación, solo codificación
> - Ambos se inyectan como **variables de entorno** o **volúmenes montados**
> - En producción: activar "Encryption at Rest" en etcd + RBAC restrictivo

---

## Paso 2: Actualizar Deployment para inyectar ConfigMap y Secret

**Qué hace:** Modificar manifiestos YAML para pasar variables de entorno desde ConfigMap y Secret a los Pods

**Por qué:** Los Pods necesitan acceso a configuración y credenciales sin codificarlas en imagen

Actualiza `k8s/deployment-service.yaml` para agregar inyección de variables:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: inventory-service
  labels:
    app: inventory-service
    version: v1.0.0
spec:
  replicas: 2
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1           # Permite 1 Pod extra durante actualización
      maxUnavailable: 0     # NUNCA permite 0 Pods: zero-downtime
  selector:
    matchLabels:
      app: inventory-service
  template:
    metadata:
      labels:
        app: inventory-service
        version: v1.0.0
    spec:
      containers:
      - name: inventory-service
        image: <tu-usuario-dockerhub>/inventory-service:1.0.0
        imagePullPolicy: Always            # Siempre tira imagen fresca de Docker Hub
        ports:
        - containerPort: 8080
          name: http
        
        # INYECCIÓN DE VARIABLES desde ConfigMap y Secret
        env:
        - name: APP_ENVIRONMENT
          valueFrom:
            configMapKeyRef:
              name: inventory-config
              key: APP_ENVIRONMENT
        - name: INVENTORY_DB_HOST
          valueFrom:
            configMapKeyRef:
              name: inventory-config
              key: INVENTORY_DB_HOST
        - name: LOG_LEVEL
          valueFrom:
            configMapKeyRef:
              name: inventory-config
              key: LOG_LEVEL
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: inventory-secrets
              key: DB_PASSWORD
        
        resources:
          requests:
            cpu: "100m"        # Crítico: HPA calcula porcentajes basado en esta solicitud
            memory: "256Mi"
          limits:
            cpu: "500m"
            memory: "512Mi"
        
        # 1. StartupProbe: ¿Arrancó la JVM correctamente?
        # Endpoint: curl http://localhost:8080/health/started
        startupProbe:
          httpGet:
            path: /health/started
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 3
          timeoutSeconds: 2
          failureThreshold: 20          # Máx 20 reintentos (60 segundos)
        
        # 2. ReadinessProbe: ¿Listo para recibir tráfico?
        # Endpoint: curl http://localhost:8080/health/ready
        readinessProbe:
          httpGet:
            path: /health/ready
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5
          timeoutSeconds: 2
          failureThreshold: 2
        
        # 3. LivenessProbe: ¿Sigue vivo o se quedó colgado?
        # Endpoint: curl http://localhost:8080/health/live
        livenessProbe:
          httpGet:
            path: /health/live
            port: 8080
          initialDelaySeconds: 10
          periodSeconds: 10
          timeoutSeconds: 2
          failureThreshold: 3

---
apiVersion: v1
kind: Service
metadata:
  name: inventory-service
  labels:
    app: inventory-service
spec:
  type: ClusterIP
  selector:
    app: inventory-service
  ports:
  - port: 80
    targetPort: 8080
    protocol: TCP
    name: http
```

### ![linux](images/linux.png) Linux/macOS

```bash
kubectl apply -f k8s/deployment-service.yaml

# Observa que los Pods se reinician con las nuevas variables
kubectl get pods -l app=inventory-service --watch
```

### ![win](images/windows.png) Windows

```powershell
kubectl apply -f k8s/deployment-service.yaml
kubectl get pods -l app=inventory-service --watch
```

### Qué observar

Los Pods **se reinician** para aplicar las nuevas variables inyectadas. Verás:

```bash
inventory-service-xxx-old  1/1   Terminating
inventory-service-xxx-new  0/1   Pending
inventory-service-xxx-new  1/1   Running
```

---

## Paso 3: Verificar inyección de variables

**Qué hace:** Validar que las variables de ConfigMap y Secret se pasaron correctamente a los Pods

**Por qué:** Asegurar que la configuración se aplicó antes de proceder

Comprueba que las variables de entorno se inyectaron correctamente:

### ![linux](images/linux.png) Linux/macOS

```bash
# Obtén el nombre de un Pod
POD_NAME=$(kubectl get pods -l app=inventory-service -o jsonpath='{.items[0].metadata.name}')

# Ejecuta env dentro del Pod
kubectl exec $POD_NAME -- env | grep -E "APP_|LOG_|DB_"
```

### ![win](images/windows.png) Windows

```powershell
$POD_NAME = kubectl get pods -l app=inventory-service -o jsonpath='{.items[0].metadata.name}'

kubectl exec $POD_NAME -- env | Select-String "APP_|LOG_|DB_"
```

### Qué observar

```bash
APP_ENVIRONMENT=production-k8s
INVENTORY_DB_HOST=db.acme.local
LOG_LEVEL=INFO
DB_PASSWORD=ProdSecure2026!
```

Todas las variables inyectadas correctamente.

### Nota pedagógica

> **NOTA PEDAGÓGICA**
>
> Comparar con Laboratorio 1:
> - Laboratorio 1.1: Mediste ~65% disponibilidad sin patrones
> - Laboratorio 1.2: Agregaste @Timeout, @Retry, @Fallback → ~90%+
> - Laboratorio 1.3: Desplegaste en K8s → ~95%+ (con salud checks)
> - **Laboratorio 2.2:** Rolling updates → zero-downtime
> - **Laboratorio 2.3:** Configuración externalizada + escalamiento automático → **arquitectura production-ready**

---

## Paso 4: Habilitar Metrics Server para HPA

**Qué hace:** Instalar componente del ecosistema Kubernetes que recolecta métricas de CPU/memoria

**Por qué:** HPA necesita datos en tiempo real para decidir cuándo escalar

El HPA necesita métricas de CPU/memoria para tomar decisiones de escalamiento.

### ![linux](images/linux.png) Linux/macOS

```bash
# Habilita metrics-server en Minikube
minikube addons enable metrics-server

# Espera a que esté listo (~30 segundos)
kubectl get pods -n kube-system | grep metrics-server

# Verifica que funciona
kubectl top pods
```

### ![win](images/windows.png) Windows

```powershell
minikube addons enable metrics-server

# Espera a que esté listo
kubectl get pods -n kube-system | Select-String "metrics-server"

# Verifica
kubectl top pods
```

### Qué observar

```bash
NAME                              CPU(m)   MEMORY(Mi)
inventory-service-xxx-abc1        5m       128Mi
inventory-service-xxx-abc2        4m       130Mi
```

Si ves valores de CPU, Metrics Server está funcionando.

---

## Paso 5: Configurar Horizontal Pod Autoscaler (HPA)

**Qué hace:** Crear objeto HPA que monitorea CPU y escala réplicas automáticamente

**Por qué:** Adapt infraestructura a variaciones de tráfico sin intervención manual

Crea `k8s/hpa.yaml`:

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: inventory-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: inventory-service
  minReplicas: 2
  maxReplicas: 6
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 50  # Escala cuando CPU > 50% del request (100m)
```

### ![linux](images/linux.png) Linux/macOS

```bash
kubectl apply -f k8s/hpa.yaml

# Monitorea el HPA
kubectl get hpa inventory-hpa --watch
```

### ![win](images/windows.png) Windows

```powershell
kubectl apply -f k8s/hpa.yaml

kubectl get hpa inventory-hpa --watch
```

### Qué observar

```bash
NAME             REFERENCE                    TARGETS     MINPODS   MAXPODS   REPLICAS
inventory-hpa    Deployment/inventory-dep     2%/50%      2         6         2
```

Significa: CPU actual es 2% del request, objetivo es 50%, por lo que **no escala** (está por debajo del umbral).

### Nota pedagógica

> **NOTA PEDAGÓGICA**
>
> La fórmula que usa el HPA:
> ```bash
> Replicas deseadas = Replicas actuales × (CPU actual / CPU objetivo)
> ```
>
> En nuestro caso:
> - Replicas actuales = 2
> - CPU actual = 5m / 100m (el request es 100m)
> - CPU objetivo = 50m
> - Replicas deseadas = 2 × (5m / 50m) = 0.2, redondeado a 2 (mínimo)
>
> Por eso con poco tráfico, no escala. Necesitamos **generar carga significativa**.

---

## Paso 6: Generar carga y observar escalamiento automático

**Qué hace:** Generar tráfico sintético para incrementar CPU por encima del umbral de HPA

**Por qué:** Validar que el escalamiento automático funciona bajo condiciones realistas

Crearemos un Pod generador dentro del clúster que consulte `http://inventory-service/v1/inventory` durante **180 segundos**, con **20 procesos concurrentes**. Cada petición abre una conexión nueva hacia el Service, permitiendo repartir tráfico entre sus Pods disponibles, incluidos los que cree el HPA. El reparto no necesariamente será uniforme.

El CPU promedio debe superar suficientemente el objetivo del HPA para escalar; no se garantiza alcanzar seis réplicas.

### Preparación (Linux, macOS y Windows)

Ejecuta todos los comandos en el **mismo namespace** donde están el Service y el HPA.

**Paso 1: Crear el archivo generador**

Crea `k8s/load-generator.yaml` en el proyecto de inventory-service:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: inventory-load-gen
  labels:
    app: inventory-load-gen
spec:
  restartPolicy: Never
  activeDeadlineSeconds: 240
  containers:
  - name: load-generator
    image: busybox:1.37
    env:
    - name: CONCURRENCY
      value: "20"
    - name: DURATION_SECONDS
      value: "180"
    resources:
      requests:
        cpu: "100m"
        memory: "32Mi"
      limits:
        cpu: "1000m"
        memory: "64Mi"
    command: ["sh", "-c"]
    args:
    - |
      URL=http://inventory-service/v1/inventory
      echo "Verificando el endpoint antes de generar carga..."
      wget -S -T 5 -O - "$URL" || {
        echo "ERROR: no se pudo consultar el endpoint; no se inicia la carga." >&2
        exit 1
      }
      echo
      echo "Iniciando $CONCURRENCY procesos durante $DURATION_SECONDS segundos."
      END=$(($(date +%s) + DURATION_SECONDS))
      PIDS=""
      for i in $(seq 1 "$CONCURRENCY"); do
        (
          COUNT=0
          while [ "$(date +%s)" -lt "$END" ]; do
            wget -q -T 5 -O /dev/null "$URL" || {
              echo "ERROR: fallo HTTP o de conexion en proceso $i." >&2
              exit 1
            }
            COUNT=$((COUNT + 1))
          done
          echo "Proceso $i: $COUNT peticiones completadas."
        ) &
        PIDS="$PIDS $!"
      done
      STATUS=0
      for PID in $PIDS; do
        wait "$PID" || STATUS=1
      done
      if [ "$STATUS" -ne 0 ]; then
        echo "ERROR: la prueba termino con peticiones fallidas." >&2
        exit 1
      fi
      echo "Carga finalizada sin errores detectados."
```

El generador tiene una etiqueta distinta a los Pods del servicio, por lo que no recibe tráfico del Service ni se incluye en las métricas del HPA. El límite de tiempo del Pod evita que una ejecución quede activa indefinidamente.

**Paso 2: Abrir tres terminales para monitoreo**

**Terminal 1 - Monitorea el HPA en tiempo real:**

```bash
kubectl get hpa inventory-hpa --watch
```

**Terminal 2 - Monitorea los Pods:**

```bash
kubectl get pods -l app=inventory-service --watch
```

**Terminal 3 - Crea y observa el generador:**

Los siguientes comandos funcionan sin cambios en Bash y PowerShell:

```bash
kubectl create -f k8s/load-generator.yaml
kubectl wait --for=condition=Ready pod/inventory-load-gen --timeout=90s
kubectl logs -f inventory-load-gen
```

En los logs, verifica que la comprobación inicial muestre **HTTP 200 y el JSON de inventory-service**. La ruta heredada del Laboratorio 2.2 es `/v1/inventory`. Si la respuesta no es la esperada o hay errores, detén el generador y diagnostica antes de aceptar la prueba como exitosa.

Durante la carga, consulta desde otra terminal el consumo por réplica:

```bash
kubectl top pods -l app=inventory-service
```

Al terminar, los logs deben mostrar el conteo de peticiones por proceso y `Carga finalizada sin errores detectados`. Verifica el estado:

```bash
kubectl get pod inventory-load-gen
```

El estado esperado es `Completed`. `Error`, `DeadlineExceeded` o errores en los logs requieren investigar la prueba. `Ctrl+C` en `kubectl logs -f` solo detiene la observación; **no detiene el generador**.

### Detener, limpiar y repetir la prueba

Para interrumpir la carga anticipadamente o eliminar el Pod una vez completado:

```bash
kubectl delete pod inventory-load-gen
```

Para repetirla, espera a que termine la eliminación y ejecuta nuevamente `kubectl create -f k8s/load-generator.yaml`. Si el promedio no supera el objetivo, puedes aumentar `CONCURRENCY` de `"20"` a `"40"` en el manifiesto y repetir, vigilando errores y recursos disponibles. No borres manualmente los Pods de inventory-service: el HPA debe reducirlos.

### Qué observar (ejemplos, no tiempos ni réplicas garantizados)

**Antes de la carga:** CPU bajo

```bash
TARGETS     MINPODS   MAXPODS   REPLICAS
2%/50%      2         6         2
```

**Durante la carga, si la CPU promedio supera suficientemente el objetivo:** El HPA puede aumentar réplicas tras actualizar las métricas

```bash
TARGETS      MINPODS   MAXPODS   REPLICAS
75%/50%      2         6         3    (escalando...)
```

**Si el promedio sigue por encima del objetivo tras escalar:** Puede haber otro aumento

```bash
TARGETS      MINPODS   MAXPODS   REPLICAS
65%/50%      2         6         4
```

**Si observas `24%/50%` con dos réplicas:** No se espera escalamiento. La estimación es `ceil(2 × 24 / 50) = 1`, pero `minReplicas: 2` mantiene dos Pods. No basta con que la CPU aumente; debe superar el objetivo, considerando también la tolerancia del HPA.

**Después de terminar la carga:** La CPU baja. La reducción de réplicas no es inmediata; por defecto, el HPA usa una ventana de estabilización de cinco minutos para reducirlas.

```bash
TARGETS     MINPODS   MAXPODS   REPLICAS
10%/50%     2         6         2    (reduciendo...)
```

### Evidencia de logs

```bash
# Ver eventos del HPA
kubectl describe hpa inventory-hpa
```

### Nota pedagógica

> **NOTA PEDAGÓGICA**
>
> Este es el **cierre del ciclo de HA**:
> - Laboratorio 1.1: Mediste disponibilidad SIN protecciones (~65%)
> - Laboratorio 1.2: Agregaste patrones de software (~90%+)
> - Laboratorio 1.3: Agregaste infraestructura multi-AZ (~95%+)
> - Laboratorio 2.2: Agregaste rolling updates sin downtime
> - **Laboratorio 2.3:** Escalas **automáticamente** según demanda real
> 
> Ahora tienes una arquitectura que:
> ✅ Se recupera de fallos (autocuración)
> ✅ Se actualiza sin interrupciones (rolling updates)
> ✅ Escala automáticamente (HPA)
> ✅ Externaliza configuración seguramente (ConfigMaps/Secrets)
> 
> **Esto es production-ready.**

---

## Guía de Troubleshooting

### Problema 1: HPA muestra `<unknown>/50%`

**Síntoma:** TARGETS no muestra métricas.

**Causa común:** Falta `resources.requests.cpu` en el Deployment.

**Solución:**

```bash
# Asegúrate que el Deployment tiene requests definidos
kubectl describe deployment inventory-service | grep -A 5 "Requests"

# Si falta, actualiza el YAML y aplica nuevamente
```

---

### Problema 2: HPA no escala aunque hay carga

**Síntoma:** Hay tráfico, pero REPLICAS permanece en 2.

**Causas posibles:** La CPU promedio sigue por debajo del objetivo, el generador falló, se usa una ruta incorrecta o hay pocos recursos para generar suficiente tráfico. Estar apenas por encima del 50% tampoco garantiza escalar, debido a la tolerancia del HPA.

**Diagnóstico:**

```bash
kubectl top pods -l app=inventory-service
kubectl describe hpa inventory-hpa
kubectl get pod inventory-load-gen
kubectl logs inventory-load-gen
```

Verifica las condiciones y eventos del HPA, la CPU por Pod y los logs del generador. Si la ruta funciona pero el promedio no supera el objetivo, aumenta `CONCURRENCY` y repite según el Paso 6. No se garantiza alcanzar seis réplicas.

---

### Problema 3: El generador no inicia o falla

**Síntoma:** `inventory-load-gen` permanece en `Pending`, muestra `ImagePullBackOff` o termina con `Error`.

**Diagnóstico (Linux, macOS y Windows):**

```bash
kubectl describe pod inventory-load-gen
kubectl logs inventory-load-gen
```

Revisa los eventos para detectar falta de recursos o errores al descargar BusyBox. Si el contenedor inició pero falla la consulta HTTP, verifica que el Service y el generador estén en el mismo namespace, que existan Pods Ready y que la ruta sea `/v1/inventory`. Corrige la causa, elimina solo el Pod generador y vuelve a crearlo.

---

## Evidencia

Entrega:

1. **ConfigMap y Secret creados:**
   - Captura de `kubectl get configmap,secret`

2. **Inyección de variables verificada:**
   - Captura de `kubectl exec ... -- env` mostrando APP_ENVIRONMENT, LOG_LEVEL, DB_PASSWORD

3. **Metrics Server funcionando:**
   - Captura de `kubectl top pods` con valores de CPU

4. **HPA escalando bajo carga:**
   - Captura de `kubectl get hpa --watch` mostrando REPLICAS aumentando por encima de 2 (sin exigir una secuencia específica ni llegar a 6)
   - Captura de `kubectl get pods` mostrando múltiples instancias en Running
   - Logs del generador con respuesta inicial HTTP 200 y finalización sin errores

5. **HPA reduciendo sin carga:**
   - Captura de `kubectl get hpa --watch` mostrando el regreso a 2 réplicas tras terminar la carga y transcurrir la estabilización

---

## Resumen de conceptos

| Concepto | Qué Hace | Cuándo Usar | Impacto |
|----------|----------|-----------|---------|
| **ConfigMap** | Almacena datos no-secretos en pares clave-valor | URLs, flags, niveles de log | Permite cambiar config sin recompilar |
| **Secret** | Almacena credenciales codificadas en base64 | Contraseñas BD, API keys, tokens | Seguridad mínima (no es encriptación) |
| **Metrics Server** | Recolecta CPU/memoria de Pods en tiempo real | HPA necesita datos para decidir | Visibilidad de consumo de recursos |
| **HPA** | Escala Pods automáticamente basado en métricas | Carga variable (picos, valles) | Ahorro de costos + rendimiento adaptativo |
| **CPU Requests** | Define solicitud mínima de CPU que necesita Pod | Todo Deployment DEBE especificar | Base de cálculo para porcentajes del HPA |

---

## Reflexión final

En Unidad 2 aprendiste:
- **Teoría:** Principios de orquestación, escalabilidad y resiliencia infraestructural
- **Práctica:** Desplegar, declarar health checks, automatizar recuperación de fallos
- **Operaciones:** Rolling updates sin downtime, externalizar configuración, escalar automáticamente

En este laboratorio cerraste el ciclo de HA iniciado en Unidad 1:
- ✅ Laboratorio 1.1: Mediste disponibilidad SIN protecciones (~65%)
- ✅ Laboratorio 1.2: Agregaste patrones de software (~90%+)
- ✅ Laboratorio 1.3: Agregaste infraestructura multi-AZ (~95%+)
- ✅ Laboratorio 2.2: Agregaste rolling updates sin downtime
- ✅ **Laboratorio 2.3:** Escalas **automáticamente** según demanda real

Ahora tienes una arquitectura que:
- ✅ Se recupera de fallos (autocuración)
- ✅ Se actualiza sin interrupciones (rolling updates)
- ✅ Escala automáticamente (HPA)
- ✅ Externaliza configuración de forma segura

Este es el modelo estándar en empresas reales: Kubernetes orquesta servicios, y tú escribes YAML declarativo que describe el estado deseado.

**¡Felicidades! Completaste Unidad 2: Orquestación Kubernetes. 🎉**

---

## Continuidad

**¡Felicidades!** Completaste la **Unidad 2: Orquestación Kubernetes**.

Has demostrado competencia en:
- Inspeccionar arquitectura interna de K8s (Laboratorio 2.1)
- Desplegar multiservicios con autocuración (Laboratorio 2.2)
- Externalizar configuración y escalar automáticamente (Laboratorio 2.3)

**Próxima unidad:** [Unidad 3 - Redes de Servicio y Seguridad](../../unidad-3-networks/README.md)

Explorarás cómo exponer servicios de forma segura y controlada:
- Ingress Controllers para ruteo L7
- NetworkPolicies para Zero Trust
- RBAC para control de acceso
- Payment-service como tercer microservicio
