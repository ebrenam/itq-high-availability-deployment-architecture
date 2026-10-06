# Laboratorio 2.2: Despliegue Multiservicios con Health Probes y Rolling Updates

## Objetivo

Crearás un **nuevo microservicio** (`inventory-service`) en Quarkus, lo desplegarás en Kubernetes junto a `catalog-service` (heredado de Unidad 1), e implementarás **Health Probes** para autorreparación y **Rolling Updates** sin tiempo de inactividad.

**Salida esperada:** Dos servicios (`catalog` e `inventory`) ejecutándose en Minikube con resiliencia infraestructural.

---

## Escenario real

> **Contexto:** Trabajas como Cloud Engineer Senior en Cortex Retail. El equipo de Unidad 1 desplegó `catalog-service` en Kubernetes. Ahora necesitas agregar `inventory-service` (nuevo componente) a la misma plataforma.
>
> **Problema:** Si cualquier Pod falla sin Health Probes, Kubernetes no lo detecta. Si necesitas actualizar imagen sin Rolling Update configurado, hay downtime. El objetivo es infraestructura de **autorreparación** y **resiliente a actualizaciones**.
>
> **Tu tarea:** Diseñar inventory-service desde cero, empaquetarlo en Docker, crear manifiestos YAML con Health Probes, desplegar AMBOS servicios, y demostrar rolling update sin interrupción de tráfico.

---

## Regla de continuidad

**Requisito previo:** Completa [Laboratorio 2.1](./laboratorio-clase-2-1.md) (conceptos de K8s)

**Conexión con Clase 2.2:** Esta clase enseña Deployments, ReplicaSets, Health Probes (StartupProbe, ReadinessProbe, LivenessProbe) y RollingUpdate. Este lab **implementa cada concepto**.

**Dependencia Anterior:** [Laboratorio 1.3](../../unidad-1-ha-architecture/02-laboratorio/laboratorio-clase-1-3.md) generó `catalog-service:1.0.0` + manifiestos YAML. **Este lab HEREDA ese código.**

**Antes de Continuar:** Completa Laboratorio 2.2 antes de [Laboratorio 2.3](./laboratorio-clase-2-3.md). Sin dominar health probes y rolling updates, no podrás escalar automáticamente en el siguiente laboratorio.

---

## Punto de partida

### Ubicación del proyecto base

```text
unidad-2-kubernetes/02-laboratorio/proyecto-base-unidad-02/
├── catalog-service/              ← HEREDADO de Laboratorio 1.3 (U1)
│   ├── src/
│   ├── pom.xml
│   ├── Dockerfile
│   └── k8s/
│       ├── 01-deployment.yaml
│       └── 02-service.yaml
│
└── [Crearás inventory-service aquí en Paso 2]
```

### Qué heredas de Unidad 1

| Componente | Origen | Estado |
|-----------|--------|--------|
| `catalog-service` | Laboratorio 1.3 (U1) | v1.0.0 con patrones de resiliencia, imagen en Docker Hub |
| `CatalogResource.java` | Laboratorio 1.2 (U1) | @Timeout, @Retry, @CircuitBreaker, @Fallback |
| `Dockerfile` | Laboratorio 1.3 (U1) | Red Hat UBI9 runtime-only, image en Docker Hub |
| Dependencias Maven | Laboratorio 1.3 (U1) | Quarkus 3.38.0, rest-jackson, smallrye-health, smallrye-fault-tolerance |
| Manifiestos YAML | Laboratorio 1.3 (U1) | Deployment (1 réplica), Service (ClusterIP) |

### Qué crearás nuevo en este laboratorio

| Componente | Acción | Salida |
|-----------|--------|--------|
| `inventory-service` | **Crear desde Maven** | v1.0.0 (nuevo microservicio) |
| `InventoryResource.java` | Implementar endpoint REST | `/v1/inventory` |
| Dockerfile | Crear y subir a Docker Hub | `<tu-usuario>/inventory-service:1.0.0` |
| Manifiestos YAML | Crear con Health Probes | Deployment (2 réplicas) + Service |

---

## Prerrequisitos y stack tecnológico

### Requisitos comunes (Linux, macOS, Windows)

- **Docker Engine** v24+ o **Podman** v4.5+
- **Minikube** v1.32+ (o **Kind** v0.20+)
- **kubectl** CLI instalado y configurado
- **Java OpenJDK** 25
- **Apache Maven** 3.9+

### Verificación

```bash
# Ejecuta estos comandos para confirmar
kubectl version --client && minikube version && java -version && mvn -version
```

### Iniciar Minikube

```bash
minikube start --cpus=4 --memory=4096
```

---

## Paso 1: Heredar `catalog-service` de Laboratorio 1.3

**Qué hace:** Asegurar que tienes el código `catalog-service` v1.0.0 (con patrones de resiliencia) como punto de partida.

**Por qué:** Laboratorio 2.2 se construye sobre Laboratorio 1.3. Necesitas el código ya compilado y el Dockerfile funcional para desplegar ambos servicios en el mismo clúster.

### Opción A: Si trabajas en secuencia (recomendado)

Copia el output de Laboratorio 1.3 a tu carpeta de trabajo:

```bash
# Desde la raíz del proyecto
cp -r unidad-1-ha-architecture/02-laboratorio/proyecto-base-unidad-01/catalog-service \
unidad-2-kubernetes/02-laboratorio/proyecto-base-unidad-02/
```

**Verifica que existe:**

```bash
cd unidad-2-kubernetes/02-laboratorio/proyecto-base-unidad-02/catalog-service
ls -la
# Deberías ver: pom.xml, src/, Dockerfile, k8s/, target/
```

### Opción B: Si retomas desde punto específico

Si hay una rama `u2-starter` en repositorio:

```bash
git checkout u2-starter
cd unidad-2-kubernetes/02-laboratorio/proyecto-base-unidad-02/
```

**Qué incluye `u2-starter`:**
- ✅ `catalog-service/` completo (Laboratorio 1.3 output)
- ✅ `CatalogResource.java` con 4 anotaciones de resiliencia
- ✅ `pom.xml` con dependencias Quarkus (rest-jackson, smallrye-health, smallrye-fault-tolerance)
- ✅ `Dockerfile` Red Hat UBI9 (heredado de Laboratorio 1.3)
- ✅ `k8s/01-deployment.yaml` y `k8s/02-service.yaml`
- ✅ Imagen `catalog-service:1.0.0` ya disponible en Docker Hub

---

## Paso 2: Crear nuevo `inventory-service` desde Maven

**Qué hace:** Genera estructura de nuevo microservicio usando Maven archetype de Quarkus.

**Por qué:** Necesitas un nuevo componente independiente para la plataforma e-commerce.

**Cambio pedagógico clave:**

- En Laboratorio 1.2 modificaste código de catalog-service (patrones de resiliencia)
- En Laboratorio 1.3 empaquetaste esa versión en Docker (v1.0.0)
- Aquí creas un nuevo servicio (inventory-service v1.0.0)
- Esto refleja crecimiento arquitectónico: de 1 a 2 microservicios

### Linux/macOS

```bash
# Asegúrate de estar en la carpeta proyecto-base-unidad-02/
cd unidad-2-kubernetes/02-laboratorio/proyecto-base-unidad-02/

# Crea nuevo servicio
mvn io.quarkus.platform:quarkus-maven-plugin:3.38.0:create \
    -DprojectGroupId=com.ecom \
    -DprojectArtifactId=inventory-service \
    -DclassName="com.ecom.inventory.InventoryResource" \
    -Dpath="/v1/inventory" \
    -Dextensions="rest-jackson,smallrye-health,smallrye-fault-tolerance"

# Entra al directorio
cd inventory-service
```

### Windows (PowerShell)

```powershell
# Asegúrate de estar en la carpeta proyecto-base-unidad-02/
cd unidad-2-kubernetes/02-laboratorio/proyecto-base-unidad-02/

# Crea nuevo servicio
mvn io.quarkus.platform:quarkus-maven-plugin:3.38.0:create `
    -DprojectGroupId=com.ecom `
    -DprojectArtifactId=inventory-service `
    -DclassName="com.ecom.inventory.InventoryResource" `
    -Dpath="/v1/inventory" `
    -Dextensions="rest-jackson,smallrye-health,smallrye-fault-tolerance"

# Entra al directorio
cd inventory-service
```

**Qué observar:**

```bash
[INFO] Your new application has been created in ../proyecto-base-unidad-02/inventory-service
[INFO] 
[INFO] ------------------------------------------------------------------------
[INFO] BUILD SUCCESS
[INFO] ------------------------------------------------------------------------
[INFO] Total time:  xx.xxx s
```

**Estructura generada (archivos clave a modificar):**

```text
inventory-service/
├── pom.xml                                (generado, sin cambios)
├── src/main/java/com/ecom/inventory/
│   └── InventoryResource.java             ← EDITAR: implementar endpoint
├── src/main/resources/
│   └── application.properties             ← EDITAR: configurar puertos y health
├── Dockerfile                             ← CREAR: multi-stage build
└── k8s/
    └── deployment-service.yaml            ← CREAR: manifiestos K8s
```

**Nota:** Maven genera muchos otros archivos (mvnw, mvnw.cmd, src/main/docker/*, test/, etc.) que ignorarás. Solo modificarás los 4 archivos listados arriba.

---

## Paso 3: Implementar Endpoint REST en `inventory-service`

**Qué hace:** Implementar un endpoint que responde requests HTTP y expone health probes.

**Por qué:** Kubernetes necesita endpoint `/health` para validar salud del servicio. El endpoint de negocio (`/v1/inventory`) simula procesamiento real.

### Abrir el proyecto en VS Code

Abre VS Code con el directorio `inventory-service`:

```bash
# Desde proyecto-base-unidad-02/
cd inventory-service

# Abre VS Code
code .
```

Para localizar los archivos a editar, usa `Ctrl+P` (o `Cmd+P` en macOS) para abrir la búsqueda rápida de archivos.

### Editar `src/main/java/com/ecom/inventory/InventoryResource.java`

Reemplaza contenido actual con:

```java
package com.ecom.inventory;

import jakarta.ws.rs.GET;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;

@Path("/v1/inventory")
public class InventoryResource {

    @GET
    @Produces(MediaType.APPLICATION_JSON)
    public InventoryStatus getStatus() {
        return new InventoryStatus("inventory-service", "UP", System.currentTimeMillis());
    }

    public record InventoryStatus(String service, String status, long timestamp) {}
}
```

**Nota Pedagógica - ¿Por qué es tan simple?**

> Notarás que `InventoryResource` es más simple que `CatalogResource` (Laboratorio 1.2). Esto es **intencional y por diseño pedagógico**:
>
> | Lab | Foco Principal | Lógica de Endpoint |
> |-----|--------|-------------------|
> | 1.2 | Patrones de resiliencia en código (@Timeout, @Retry, @CircuitBreaker, @Fallback) | Compleja: simula latencia, fallos DB, degradación |
> | 2.2 | Resiliencia infraestructural (Health Probes, Rolling Updates, autorreparación) | Simple: solo retorna estado de salud |
>
> **Razón:** En Laboratorio 2.2 el enfoque es **Kubernetes**, no lógica de negocio. Ya dominas patrones resilientes en código (Laboratorio 1.2). Aquí practicas cómo la infraestructura K8s detecta fallos (Health Probes) y se recupera automáticamente (self-healing y rolling updates).
>
> **En producción:** Este endpoint simple simula un inventario. En realidad consultaría una BD, pero aquí simplificamos para mantener foco en K8s.

### Editar `src/main/resources/application.properties`

**Instrucción:**

- En VS Code, usa `Ctrl+P` para abrir `application.properties`
- Puede estar vacío o con contenido mínimo
- Reemplaza TODO el contenido con lo siguiente:

```properties
# HTTP Configuration
quarkus.http.port=8080
quarkus.http.host=0.0.0.0

# Application Metadata
quarkus.application.name=inventory-service
quarkus.application.version=1.0.0

# Health Check Configuration
quarkus.smallrye-health.root-path=/health
```

**Qué hace esta configuración:**
- `quarkus.http.port=8080`: Mismo puerto que catalog-service. Cada Pod tiene su propio puerto privado en la red K8s
- `quarkus.http.host=0.0.0.0`: **CRÍTICO para K8s.** Escucha en todas las interfaces de red del contenedor. Sin esto, Kubernetes no podría acceder a los health probes
- `quarkus.smallrye-health.root-path=/health`: Kubernetes consultará automáticamente los endpoints `/health/started`, `/health/ready`, `/health/live` para validar salud
- Metadata de aplicación: Para tracking en logs y observabilidad (útil cuando inspecciones Pods en producción)

**Guarda el archivo:** `Ctrl+S` (o `Cmd+S` en macOS)

### Verifica compilación

```bash
# Desde directorio inventory-service/
mvn clean package -DskipTests
```

**Qué observar:**

```text
[INFO] Building inventory-service 1.0.0-SNAPSHOT
[INFO]   from pom.xml
[INFO]
[INFO] ------------------------------------------------------------------------
[INFO] BUILD SUCCESS
[INFO] ------------------------------------------------------------------------
[INFO] Total time:  x.xxx s
```

---

## Paso 4: Crear Dockerfile

**Qué hace:** Empaquetar aplicación Java compilada en imagen Docker lista para Kubernetes.

**Por qué:** Docker empaqueta solo el JAR (sin herramientas de build), reduciendo tamaño y riesgo de seguridad. Este Dockerfile es idéntico al que usaste en Laboratorio 1.3 con `catalog-service`.

### Crear `Dockerfile` en raíz de `inventory-service/`

```dockerfile
FROM registry.access.redhat.com/ubi9/openjdk-25-runtime:1.24

ENV LANGUAGE='en_US:en'

# We make four distinct layers so if there are application changes the library layers can be re-used
COPY --chown=185 target/quarkus-app/lib/ /deployments/lib/
COPY --chown=185 target/quarkus-app/*.jar /deployments/
COPY --chown=185 target/quarkus-app/app/ /deployments/app/
COPY --chown=185 target/quarkus-app/quarkus/ /deployments/quarkus/

EXPOSE 8080
USER 185
ENV JAVA_OPTS_APPEND="-Dquarkus.http.host=0.0.0.0 -Djava.util.logging.manager=org.jboss.logmanager.LogManager"
ENV JAVA_APP_JAR="/deployments/quarkus-run.jar"

ENTRYPOINT [ "/opt/jboss/container/java/run/run-java.sh" ]
```

### Compilar imagen Docker y subirla a Docker Hub

**Linux/macOS:**

```bash
# Ingresar credenciales de Docker Hub
docker login

# Compila imagen con tu usuario de Docker Hub
docker build -t <tu-usuario-dockerhub>/inventory-service:1.0.0 .

# Sube imagen a Docker Hub (importante para reutilizar en otros ambientes/labs)
docker push <tu-usuario-dockerhub>/inventory-service:1.0.0
```

**Windows (PowerShell):**

```powershell
# Ingresar credenciales de Docker Hub
docker login

# Compila imagen con tu usuario de Docker Hub
docker build -t <tu-usuario-dockerhub>/inventory-service:1.0.0 .

# Sube imagen a Docker Hub (importante para reutilizar en otros ambientes/labs)
docker push <tu-usuario-dockerhub>/inventory-service:1.0.0
```

**Qué observar (Build):**

```text
[+] Building 12.0s (10/10) FINISHED                                              docker:default
 => [internal] load build definition from Dockerfile                                  0.0s
 => [internal] load metadata for registry.access.redhat.com/ubi9/openjdk-25-runtime   0.9s
 => [1/5] FROM registry.access.redhat.com/ubi9/openjdk-25-runtime:1.24...             9.9s
 => [2/5] COPY --chown=185 target/quarkus-app/lib/ /deployments/lib/                  0.4s
 => [3/5] COPY --chown=185 target/quarkus-app/*.jar /deployments/                     0.1s
 => [4/5] COPY --chown=185 target/quarkus-app/app/ /deployments/app/                  0.1s
 => [5/5] COPY --chown=185 target/quarkus-app/quarkus/ /deployments/quarkus/          0.1s
 => => exporting to image                                                             0.2s
 => => naming to docker.io/<tu-usuario-dockerhub>/inventory-service:1.0.0             0.0s
```

**Qué observar (Push a Docker Hub):**

```text
The push refers to repository [docker.io/<tu-usuario-dockerhub>/inventory-service]
0f19d5827301: Pushed 
92aa584288c5: Pushed 
609668031325: Pushed 
9d0ff58d2f28: Pushed 
274918f67a30: Pushed 
15bd75a4e0d9: Pushed 
1.0.0: digest: sha256:21d1b2356e6fae0dddcc0b8e80573a428b5094ae44f04752233be51b64665a80 size: 1580
```

### Nota Pedagógica - Por qué Docker Hub (no local Minikube)

> **¿Por qué subirla a Docker Hub ahora?**
>
> Aunque podrías compilar localmente en Minikube, lo correcto es Docker Hub porque:
>
> | Ventaja | Implicación |
> |--------|-----|
> | Reutilizable en otros labs | Laboratorio 2.3 y futuras unidades pueden usar la misma imagen |
> | Consistente con catalog-service | Laboratorio 1.3 ya subió `catalog-service` a Docker Hub |
> | Realista/profesional | En producción SIEMPRE usas registro remoto (Docker Hub, ECR, GCR, etc.) |
> | Sin dependencies locales | Otro developer o ambiente puede tirar la imagen sin Minikube |
>
> **Flujo profesional:**
> ```bash
> 1. Compilar: mvn clean package            ← En tu máquina
> 2. Empaquetar: docker build               ← En tu máquina
> 3. Subir: docker push a Docker Hub        ← Permanente, accesible globalmente
> 4. Desplegar: kubectl pull de Docker Hub  ← Cualquier K8s cluster
> ```
>
> **Comparación:**
>
> | Método | Ventajas | Desventajas |
> |--------|----------|-------------|
> | Local Minikube | Rápido para testing | Solo funciona en TU máquina |
> | Docker Hub | Reutilizable, profesional | Pequeño delay de push/pull |
>
> **Reemplaza `<tu-usuario-dockerhub>` con tu usuario real**
>
> **Este Dockerfile es el MISMO que usaste en Laboratorio 1.3** con catalog-service. La diferencia es que ahora subes a Docker Hub desde el inicio, asegurando reutilización en futuros labs.

---

## Paso 5: Crear Manifiestos YAML con Health Probes

**Qué hace:** Definir cómo Kubernetes ejecutará inventory-service con configuración de resiliencia.

**Por qué:** Kubernetes necesita saber:
- Cuántas réplicas ejecutar (resiliencia a fallos)
- Cómo actualizar sin downtime (rolling updates)
- Si un Pod está listo para tráfico (readiness probe)
- Si un Pod sigue vivo (liveness probe)

### Crear directorio `k8s/` en raíz del proyecto

```bash
# Desde la raíz de inventory-service/
mkdir -p k8s
cd k8s
```

### Crear `k8s/deployment-service.yaml`

**Nota sobre estructura de manifiestos:**

Tienes 2 opciones (equivalentes):

| Opción | Archivos | Ventaja | Desventaja |
|--------|----------|---------|-----------|
| **Combinado (recomendado aquí)** | 1 archivo: `deployment-service.yaml` | Menos archivos, más simple | Archivo más largo |
| **Separado (como catalog-service)** | 2 archivos: `deployment.yaml` + `service.yaml` | Más modular, fácil editar por separado | Más archivos |

**En este lab usaremos combinado** para simplicidad. Si prefieres separado, solo divide en 2 archivos (igual estructura interna).

**Diferencias con catalog-service (Unidad 1):**

| Aspecto | catalog-service (U1) | inventory-service (U2) | Razón |
|--------|-------|--------|------|
| Replicas | 1 | 2 | U2 enfatiza alta disponibilidad |
| Health Probes | 2 tipos (/ready, /live) | 3 tipos (/health/started, /health/ready, /health/live) | Quarkus 3.38 con smallrye-health expone 3 endpoints |
| RollingUpdate | Implícito (defaults) | Explícito (maxSurge: 1, maxUnavailable: 0) | U2 enseña rolling updates avanzadas y cero-downtime |
| imagePullPolicy | IfNotPresent | Always | Docker Hub asegura última versión en cada despliegue |
| Resources | No definidos | Sí (requests + limits) | U2 añade resource management y QoS |
| timeoutSeconds | No especificado (1s default) | Explícito en probes | U2 enseña control fino de health checks |
| Nomenclatura labels | `app: catalog-service`, `version: v1.0.0` | `app: inventory-service`, `version: v1.0.0` | Mismo patrón simple y consistente |

---

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
        resources:
          requests:
            cpu: "100m"
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

**Si prefieres archivos separados (como catalog-service):**

Puedes dividir `deployment-service.yaml` en 2 archivos:
- `01-deployment.yaml`: Contiene solo la sección `Deployment` (sin `---` final)
- `02-service.yaml`: Contiene solo la sección `Service`

Ambas opciones funcionan idénticamente, el resultado es exactamente el mismo.

---

### Desplegar ambos servicios

**Punto de partida:** Asumir que estás en la raíz del proyecto

```bash
cd unidad-2-kubernetes/02-laboratorio/proyecto-base-unidad-02/
pwd  # Verifica: deberías ver .../proyecto-base-unidad-02
```

**Paso 1: Desplegar catalog-service (heredado)**

```bash
# Desde proyecto-base-unidad-02/, accede a catalog-service
cd catalog-service/k8s

# Aplica manifiestos
kubectl apply -f 01-deployment.yaml -f 02-service.yaml

# Verifica (aún en proyecto-base-unidad-02/catalog-service/k8s/)
kubectl get pods -l app=catalog-service
```

**Paso 2: Desplegar inventory-service (nuevo)**

```bash
# Desde proyecto-base-unidad-02/catalog-service/k8s/, regresa a raíz del proyecto
cd ../..
pwd  # Verifica: deberías ver .../proyecto-base-unidad-02

# Accede a inventory-service
cd inventory-service/k8s

# Aplica manifiestos
kubectl apply -f deployment-service.yaml

# Verifica (aún en proyecto-base-unidad-02/inventory-service/k8s/)
kubectl get pods -l app=inventory-app
```

**Paso 3: Verificar ambos servicios desplegados**

```bash
# Regresa a la raíz para ver todos los Pods y Services
cd ../..

# Ver todos los Pods (ambos servicios)
kubectl get pods

# Ver todos los Services (ambos servicios)
kubectl get svc
```

**Qué observar:**

```text
NAME                               READY   STATUS    RESTARTS
catalog-service-xxx-abc1           1/1     Running   0       
inventory-service-xxx-abc1         1/1     Running   0       
inventory-service-xxx-abc2         1/1     Running   0       

NAME                  TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S) 
catalog-service       ClusterIP   10.96.xxx.xxx   <none>        8080/TCP
inventory-service     ClusterIP   10.96.yyy.yyy   <none>        80/TCP  
```

**Análisis de salida:**

- **catalog-service-xxx-abc1:** 1 Pod en Running (Laboratorio 1.3, heredado)
- **inventory-service-xxx-abc1 y xxx-abc2:** 2 Pods en Running (nuevo, despliegue actual)
- Todos los Pods están `Ready` (1/1) y sin `RESTARTS`
- CLUSTER-IP diferente para cada servicio (asignados automáticamente por Kubernetes)

---

## Paso 6: Validar Health Probes

**Qué hace:** Verificar que los 3 tipos de probes funcionan correctamente.

**Por qué:** Sin health probes, Kubernetes no sabe detectar Pods fallidos.

### Inspeccionar Probes de un Pod

```bash
# Obtener nombre de Pod
POD_NAME=$(kubectl get pods -l app=inventory-service -o jsonpath='{.items[0].metadata.name}')

# Ver detalles incluyendo probes
kubectl describe pod $POD_NAME

# Busca estas líneas:
# Liveness Probe:   http-get http://:8080/health/live delay=0s timeout=1s period=10s #success=1 #failure=3
# Readiness Probe:  http-get http://:8080/health/ready delay=0s timeout=1s period=5s #success=1 #failure=2
# Startup Probe:    http-get http://:8080/health/started delay=5s timeout=1s period=3s #success=1 #failure=20
```

### Prueba endpoints de salud directamente

**Prueba 1: StartupProbe - ¿Arrancó la JVM?**

```bash
# Acceder a Pod local
kubectl exec -it $POD_NAME -- curl localhost:8080/health/started
```

**Qué observar:**

```json
{
  "status": "UP",
  "checks": []
}
```

**Qué significa:** La JVM arrancó correctamente. Kubernetes permite que el ReadinessProbe comience.

---

**Prueba 2: ReadinessProbe - ¿Está listo para tráfico?**

```bash
# Acceder a Pod local
kubectl exec -it $POD_NAME -- curl localhost:8080/health/ready
```

**Qué observar:**

```json
{
  "status": "UP",
  "checks": []
}
```

**Qué significa:** El servicio está listo. Kubernetes incluye este Pod en el Service load balancer.

---

**Prueba 3: LivenessProbe - ¿Está vivo o bloqueado?**

```bash
# Acceder a Pod local
kubectl exec -it $POD_NAME -- curl localhost:8080/health/live
```

**Qué observar:**

```json
{
  "status": "UP",
  "checks": []
}
```

**Qué significa:** El servicio está vivo (no bloqueado). Si fallara 3 veces, Kubernetes REINICIARÍA el contenedor.

---

**Resumen de las 3 pruebas:**

| Probe          | Endpoint          | Significado        | Acción si falla           |
| -------------- | ----------------- | ------------------ | ------------------------- |
| StartupProbe   | `/health/started` | JVM arrancó        | Reintentar (max 20×)      |
| ReadinessProbe | `/health/ready`   | Listo para servir  | Remover del load balancer |
| LivenessProbe  | `/health/live`    | Sigue respondiendo | Reiniciar contenedor      |

### Nota Pedagógica

> Los 3 tipos de probes estudiaste en Clase 2.2:
> - **StartupProbe:** Espera hasta 60 segundos (20 × 3 seg) para que Quarkus arranque
> - **ReadinessProbe:** Si falla 2 veces consecutivas, K8s remueve Pod del Service load balancer (NO destruye)
> - **LivenessProbe:** Si falla 3 veces, K8s REINICIA el contenedor para recuperarse de bloqueos
>
> Sin estas sondas, K8s seguiría enviando tráfico a Pods fallidos → BAD EXPERIENCE.

---

## Paso 7: Demostrar Autorreparación (Self-Healing)

**Qué hace:** Eliminar manualmente un Pod y verificar que Kubernetes lo regenera automáticamente.

**Por qué:** Demuestra que la infraestructura se recupera sin intervención manual.

### Eliminar un Pod manualmente

```bash
# Obtener nombre de un Pod
TARGET_POD=$(kubectl get pods -l app=inventory-service -o jsonpath='{.items[0].metadata.name}')

# Eliminar Pod
kubectl delete pod $TARGET_POD

# Monitorear creación de reemplazo
kubectl get pods -l app=inventory-service --watch
```

**Qué observar:**

```
NAME                                  READY   STATUS      RESTARTS   AGE
inventory-service-xxx-abc1         0/1     Terminating 0          2m
inventory-service-xxx-abc3         0/1     Pending     0          1s
inventory-service-xxx-abc3         1/1     Running     0          5s
```

El ReplicaSet detectó que faltaba una réplica y creó automáticamente un nuevo Pod. **Esta es la autorreparación en acción.**

---

> Faltan pasos para terminar este laboratorio...