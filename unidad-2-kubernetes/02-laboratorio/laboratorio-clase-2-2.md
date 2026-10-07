# Laboratorio 2.2: Despliegue Multiservicios con Health Checks y Rolling Updates

## Objetivo

Crearás un **nuevo microservicio** (`inventory-service`) en Quarkus, lo desplegarás en Kubernetes junto a `catalog-service` (heredado de Unidad 1), e implementarás **Health Checks** para autorreparación y **Rolling Updates** sin tiempo de inactividad.

**Salida esperada:** Dos servicios (`catalog` e `inventory`) ejecutándose en Minikube con resiliencia infraestructural.

---

## Escenario real

> **Contexto:** Trabajas como Cloud Engineer Senior en Cortex Retail. El equipo de Unidad 1 desplegó `catalog-service` en Kubernetes. Ahora necesitas agregar `inventory-service` (nuevo componente) a la misma plataforma.
>
> **Problema:** Si cualquier Pod falla sin Health Checks, Kubernetes no lo detecta. Si necesitas actualizar imagen sin Rolling Update configurado, hay downtime. El objetivo es infraestructura de **autorreparación** y **resiliente a actualizaciones**.
>
> **Tu tarea:** Diseñar inventory-service desde cero, empaquetarlo en Docker, crear manifiestos YAML con Health Checks, desplegar AMBOS servicios, y demostrar rolling update sin interrupción de tráfico.

---

## Regla de continuidad

**Requisito previo:** Completa [Laboratorio 2.1](./laboratorio-clase-2-1.md) (conceptos de K8s)

**Conexión con Clase 2.2:** Esta clase enseña Deployments, ReplicaSets, Health Checks (StartupProbe, ReadinessProbe, LivenessProbe) y RollingUpdate. Este lab **implementa cada concepto**.

**Dependencia Anterior:** [Laboratorio 1.3](../../unidad-1-ha-architecture/02-laboratorio/laboratorio-clase-1-3.md) generó `catalog-service:1.0.0` + manifiestos YAML. **Este lab HEREDA ese código.**

**Antes de Continuar:** Completa Laboratorio 2.2 antes de [Laboratorio 2.3](./laboratorio-clase-2-3.md). En Lab 2.3, trabajarás con estos mismos dos servicios (catalog-service e inventory-service) para implementar escalamiento automático (HPA - Horizontal Pod Autoscaler) basado en métricas de CPU y memoria.

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
| Manifiestos YAML | Crear con Health Checks | Deployment (2 réplicas) + Service |

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

**Por qué:** Laboratorio 2.2 usa Laboratorio 1.3 como referencia. Necesitas el código ya compilado y el Dockerfile funcional de catalog-service para desplegar ambos servicios en el mismo clúster.

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

### ![linux](images/linux.png) Linux/macOS

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

### ![win](images/windows.png) Windows (PowerShell)

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

![linux](images/linux.png) **Linux/macOS:**

```bash
# Ingresar credenciales de Docker Hub
docker login

# Compila imagen con tu usuario de Docker Hub
docker build -t <tu-usuario-dockerhub>/inventory-service:1.0.0 .

# Sube imagen a Docker Hub (importante para reutilizar en otros ambientes/labs)
docker push <tu-usuario-dockerhub>/inventory-service:1.0.0
```

![windows](images/windows.png) **Windows (PowerShell):**

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
> | Realista/profesional | En producción siempre usas registro remoto (Docker Hub, ECR, GCR, etc.) |
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
> | Local Minikube | Rápido para testing | Solo funciona en tu máquina |
> | Docker Hub | Reutilizable, profesional | Pequeño delay de push/pull |
>
> **Reemplaza `<tu-usuario-dockerhub>` con tu usuario real**
>
> **Este Dockerfile es el mismo que usaste en Laboratorio 1.3** con catalog-service. La diferencia es que ahora subes a Docker Hub desde el inicio, asegurando reutilización en futuros labs.

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
| Health Checks | 2 tipos (/ready, /live) | 3 tipos (/health/started, /health/ready, /health/live) | Quarkus 3.38 con smallrye-health expone 3 endpoints |
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
kubectl get pods -l app=inventory-service
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

## Paso 6: Validar Health Checks

**Qué hace:** Verificar que los 3 tipos de health checks funcionan correctamente.

**Por qué:** Sin health checks, Kubernetes no sabe detectar Pods fallidos.

### ![linux](images/linux.png) Instrucciones para Linux/macOS

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

### ![win](images/windows.png) Instrucciones para Windows

```powershell
# Obtener nombre de Pod
$POD_NAME = kubectl get pods -l app=inventory-service -o jsonpath='{.items[0].metadata.name}'

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

**Qué significa:** El servicio está vivo (no bloqueado). Si fallara 3 veces, Kubernetes reiniciaría el contenedor.

### ![win](images/windows.png) Prueba endpoints de salud (Windows)

**Prueba 1: StartupProbe - ¿Arrancó la JVM?**

```powershell
kubectl exec -it $POD_NAME -- curl localhost:8080/health/started
```

**Prueba 2: ReadinessProbe - ¿Está listo para tráfico?**

```powershell
kubectl exec -it $POD_NAME -- curl localhost:8080/health/ready
```

**Prueba 3: LivenessProbe - ¿Está vivo o bloqueado?**

```powershell
kubectl exec -it $POD_NAME -- curl localhost:8080/health/live
```

**Qué observar en las 3 pruebas:**

Los resultados esperados son idénticos en Windows y Linux/macOS.

---

**Resumen de las 3 pruebas:**

| Probe          | Endpoint          | Significado        | Acción si falla           |
| -------------- | ----------------- | ------------------ | ------------------------- |
| StartupProbe   | `/health/started` | JVM arrancó        | Reintentar (max 20×)      |
| ReadinessProbe | `/health/ready`   | Listo para servir  | Remover del load balancer |
| LivenessProbe  | `/health/live`    | Sigue respondiendo | Reiniciar contenedor      |

### Nota Pedagógica

> Los 3 tipos de health checks (probes) que estudiaste en Clase 2.2:
> - **StartupProbe:** Espera hasta 60 segundos (20 × 3 seg) para que Quarkus arranque
> - **ReadinessProbe:** Si falla 2 veces consecutivas, K8s remueve Pod del Service load balancer (NO destruye)
> - **LivenessProbe:** Si falla 3 veces, K8s REINICIA el contenedor para recuperarse de bloqueos
>
> Sin estos health checks, K8s seguiría enviando tráfico a Pods fallidos → BAD EXPERIENCE.

---

## Paso 7: Demostrar Autorreparación (Self-Healing)

**Qué hace:** Eliminar manualmente un Pod y verificar que Kubernetes lo regenera automáticamente.

**Por qué:** Demuestra que la infraestructura se recupera sin intervención manual.

### Eliminar un Pod manualmente

### ![linux](images/linux.png) Linux/macOS

**Paso 1: Ver estado actual (2 Pods corriendo)**

```bash
kubectl get pods -l app=inventory-service
```

**Qué observar:**

```bash
NAME                                  READY   STATUS    RESTARTS   AGE
inventory-service-xxx-abc1            1/1     Running   0          5m
inventory-service-xxx-abc2            1/1     Running   0          4m
```

**Paso 2: Primero abre otra terminal y preparar el "monitor" (--watch)**

Abre una **segunda terminal** y ejecuta:

```bash
# Terminal 2: Este comando se queda esperando cambios EN VIVO
kubectl get pods -l app=inventory-service --watch
```

**Qué ver:** La salida inicial mostrará los 2 Pods en Running. El cursor se quedará esperando cambios (no termina).

**Paso 3: Después vuelve a terminal original y eliminar el Pod**

Vuelve a la **primera terminal** y ejecuta:

```bash
# Terminal 1: Obtener nombre del primer Pod y eliminarlo
TARGET_POD=$(kubectl get pods -l app=inventory-service -o jsonpath='{.items[0].metadata.name}')

# Eliminar el Pod
kubectl delete pod $TARGET_POD
```

**Paso 4: Observar en Terminal 2 cómo se recupera en tiempo real**

**En la terminal 2** verás la secuencia de cambios:

```bash
NAME                                  READY   STATUS      RESTARTS   AGE
inventory-service-xxx-abc1            1/1     Running     0          5m
inventory-service-xxx-abc2            1/1     Running     0          4m

# Momento 1: Pod se marca para eliminar
inventory-service-xxx-abc1            0/1     Terminating 0          5m

# Momento 2: ReplicaSet detecta que falta una réplica
inventory-service-xxx-abc3            0/1     Pending     0          1s

# Momento 3: Se crea el nuevo contenedor
inventory-service-xxx-abc3            0/1     ContainerCreating 0    2s

# Momento 4: Nuevo Pod pasa readiness
inventory-service-xxx-abc3            1/1     Running     0          5s

# Momento 5: Pod viejo termina completamente
inventory-service-xxx-abc1            0/1     Terminating 0          5m
inventory-service-xxx-abc1            0/1     Terminating 0          5m
```

**El ReplicaSet detectó la falta de réplica y la recreó automáticamente. Esto es la autorreparación.**

### ![win](images/windows.png) Windows

**Paso 1: Ver estado actual (2 Pods corriendo)**

```powershell
kubectl get pods -l app=inventory-service
```

**Qué observar:**

```powershell
NAME                                  READY   STATUS    RESTARTS   AGE
inventory-service-xxx-abc1            1/1     Running   0          5m
inventory-service-xxx-abc2            1/1     Running   0          4m
```

**Paso 2: Primero abre otra terminal de PowerShell y preparar el "monitor" (--watch)**

Abre una **segunda terminal PowerShell** y ejecuta:

```powershell
# Terminal 2: Este comando se queda esperando cambios EN VIVO
kubectl get pods -l app=inventory-service --watch
```

**Qué ver:** La salida inicial mostrará los 2 Pods en Running. El cursor se quedará esperando cambios (no termina).

**Paso 3: Después vuelve a terminal original y eliminar el Pod**

Vuelve a la **primera terminal PowerShell** y ejecuta:

```powershell
# Terminal 1: Obtener nombre del primer Pod y eliminarlo
$TARGET_POD = kubectl get pods -l app=inventory-service -o jsonpath='{.items[0].metadata.name}'

# Eliminar el Pod
kubectl delete pod $TARGET_POD
```

**Paso 4: Observar en Terminal 2 cómo se recupera en tiempo real**

**En la terminal 2** verás la secuencia de cambios:

```powershell
NAME                                  READY   STATUS      RESTARTS   AGE
inventory-service-xxx-abc1            1/1     Running     0          5m
inventory-service-xxx-abc2            1/1     Running     0          4m

# Momento 1: Pod se marca para eliminar
inventory-service-xxx-abc1            0/1     Terminating 0          5m

# Momento 2: ReplicaSet detecta que falta una réplica
inventory-service-xxx-abc3            0/1     Pending     0          1s

# Momento 3: Se crea el nuevo contenedor
inventory-service-xxx-abc3            0/1     ContainerCreating 0    2s

# Momento 4: Nuevo Pod pasa readiness
inventory-service-xxx-abc3            1/1     Running     0          5s

# Momento 5: Pod viejo termina completamente
inventory-service-xxx-abc1            0/1     Terminating 0          5m
inventory-service-xxx-abc1            0/1     Terminating 0          5m
```

**El ReplicaSet detectó la falta de réplica y la recreó automáticamente. Esto es la autorreparación.**

---

## Paso 8: Demostrar Rolling Update sin downtime

**Qué hace:** Actualizar imagen del Deployment mostrando transición gradual sin interrupción de tráfico.

**Por qué:** Demuestra que `maxUnavailable: 0` garantiza cero-downtime durante actualizaciones.

### Paso 8.1: Hacer cambio en código (versión 1.1.0)

Abre `src/main/java/com/ecom/inventory/InventoryResource.java` y modifica el `record`:

**Cambio pequeño pero medible:**

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
        return new InventoryStatus("inventory-service", "UP", System.currentTimeMillis(), "v1.1.0");
    }

    // CAMBIO: Agregamos campo 'version' al record
    public record InventoryStatus(String service, String status, long timestamp, String version) {}
}
```

**Qué cambió:**
- Nuevo parámetro `version` en el `record` (ahora son 4 campos en lugar de 3)
- El endpoint retorna `"v1.1.0"` en cada respuesta
- Esto permite verificar que el rolling update completó exitosamente

### Paso 8.2: Compilar y empaquetar nueva versión

```bash
# Desde directorio inventory-service/
mvn clean package -DskipTests
```

**Qué observar:**

```bash
[INFO] Building inventory-service 1.0.0-SNAPSHOT
[INFO] BUILD SUCCESS
```

**Nota Pedagógica - ¿Por qué la versión es todavía 1.0.0-SNAPSHOT?**

> Notarás que el output dice `1.0.0-SNAPSHOT` aunque vamos a crear una imagen Docker `1.1.0`. Esto es intencional: hay **3 niveles de versionamiento independientes** (Maven, Código Java, Docker).
>
> **Lectura recomendada:** [Anexo: Versionamiento en Java/Maven/Docker](../01-clase/anexo-versionamiento.md)
>
> **TL;DR:** En este laboratorio:
> - `pom.xml` = 1.0.0-SNAPSHOT (no cambia)
> - Código Java = "v1.1.0" hardcoded (Tú lo cambias)
> - Docker tag = 1.1.0 (Tú lo asignas en `docker build -t`)
>
> Todos son **independientes pero coordinados**.

### Paso 8.3: Compilar imagen Docker v1.1.0

```bash
# Aún en inventory-service/
docker build -t <tu-usuario-dockerhub>/inventory-service:1.1.0 .
```

**Qué observar:**

```text
[+] Building 8.5s (10/10) FINISHED                                              docker:default
 => [1/5] FROM registry.access.redhat.com/ubi9/openjdk-25-runtime:1.24...       0.0s
 => [2/5] COPY --chown=185 target/quarkus-app/lib/ /deployments/lib/            0.2s
 => [3/5] COPY --chown=185 target/quarkus-app/*.jar /deployments/               0.1s
 => [4/5] COPY --chown=185 target/quarkus-app/app/ /deployments/app/            0.1s
 => [5/5] COPY --chown=185 target/quarkus-app/quarkus/ /deployments/quarkus/    0.1s
 => => naming to docker.io/<tu-usuario-dockerhub>/inventory-service:1.1.0       0.0s
```

### Paso 8.4: Subir imagen a Docker Hub

```bash
# Aún en inventory-service/
docker push <tu-usuario-dockerhub>/inventory-service:1.1.0
```

**Qué observar:**

```text
The push refers to repository [docker.io/<tu-usuario-dockerhub>/inventory-service]
7f3e2a1b4c5d: Pushed
5c4b3a2e1f0g: Pushed
4d3c2b1a0f9e: Pushed
3c2b1a0f9e8d: Pushed
1.1.0: digest: sha256:abc123def456... size: 1620
```

### Paso 8.5: Simular tráfico continuo (terminal 1)

**Importante:** Si existe un pod `load-gen` anterior de un intento previo, elimínalo primero:

```bash
# Eliminar pod anterior si existe (forzado para más rapidez)
kubectl delete pod load-gen --ignore-not-found=true --grace-period=0 --force
```

Luego, crea el nuevo generador de tráfico:

```bash
# Vuelve a proyecto-base-unidad-02/
cd ../..

# Ejecutar generador de requests en background
# Este comando hace GET cada 1 segundo al endpoint /v1/inventory
kubectl run load-gen --image=busybox \
  -- sh -c "while true; do TS=\$(date +%H:%M:%S); RESULT=\$(wget -q -O- http://inventory-service/v1/inventory 2>&1 || echo 'error'); echo \"[\$TS] \$RESULT\"; sleep 1; done" &
```

**Qué hace:**
- `echo "[$(date +%H:%M:%S)]"`: Muestra timestamp de cada intento (HH:MM:SS)
- `wget -q -O-`: Descarga el contenido y lo imprime a stdout
- `http://inventory-service/v1/inventory`: Accede al servicio por DNS interno de Kubernetes
- `sleep 1`: Espera 1 segundo entre requests
- `|| echo 'error'`: Si wget falla, imprime "error" (problemas de conexión)

**Qué observar en el output (terminal 1):**

Verás inmediatamente:

```bash
pod/load-gen created
```

**Ahora haz Ctrl+C en Terminal 1** (esto mata solo el proceso bash local, NO el Pod):

```bash
^C
```

**Luego, en la misma Terminal 1, ejecuta:**

```bash
# Ver salida de load-gen EN VIVO
kubectl logs -f load-gen
```

**Qué debería ver en Terminal 1 (después de Ctrl+C y `kubectl logs -f`):**

```bash
[17:47:00] {"service":"inventory-service","status":"UP","timestamp":1791330421680}
[17:47:01] {"service":"inventory-service","status":"UP","timestamp":1791330422683}
[17:47:02] {"service":"inventory-service","status":"UP","timestamp":1791330423687}
[17:47:03] error
[17:47:04] {"service":"inventory-service","status":"UP","timestamp":1791330425695}
[17:47:05] {"service":"inventory-service","status":"UP","timestamp":1791330426698}
[17:47:06] {"service":"inventory-service","status":"UP","timestamp":1791330427701}
```

**Interpretación:**
- ✅ Cada línea comienza con `[HH:MM:SS]` seguida del response JSON o "error"
- ✅ `{"service":"inventory-service",...}` = respuesta exitosa del servicio
- ❌ `error` = conexión rechazada (indica downtime)
- **Durante rolling update: máximo 1-2 "error" (no consecutivos) es NORMAL**
- **MUCHOS "error" consecutivos = downtime crítico (problema con tu configuración)**

### Paso 8.6: Monitorear pods durante actualización (terminal 2)

**Abre otra terminal (Terminal 2)** y monitorea los Pods:

```bash
# Terminal 2: En paralelo a Terminal 1
cd unidad-2-kubernetes/02-laboratorio/proyecto-base-unidad-02/

# Monitorea actualización en tiempo real
kubectl get pods -l app=inventory-service --watch
```

**Resumen del flujo (2 terminales en vivo):**
- **Terminal 1:** `kubectl run load-gen` → Ctrl+C → `kubectl logs -f load-gen` (ver logs EN VIVO)
- **Terminal 2:** `kubectl get pods --watch` (monitorea cambios de pods EN VIVO)

Ambas trabajan en paralelo.

### Paso 8.7: Ejecutar Rolling Update (terminal 3)

Manteniendo la Terminal 1 y 2 en vivo, en una **tercera terminal** ejecuta la actualización:

**Estado en este momento:**
- **Terminal 1:** `kubectl logs -f load-gen` (logs EN VIVO - no interrumpir)
- **Terminal 2:** `kubectl get pods --watch` (pods EN VIVO - no interrumpir)
- **Terminal 3:** Aquí ejecutas la actualización

### ![linux](images/linux.png) Linux/macOS

```bash
# Actualizar a versión 1.1.0
kubectl set image deployment/inventory-service \
  inventory-service=<tu-usuario-dockerhub>/inventory-service:1.1.0

# Ver progreso
kubectl rollout status deployment/inventory-service
```

### ![win](images/windows.png) Windows

```powershell
# Actualizar a versión 1.1.0
kubectl set image deployment/inventory-service `
  inventory-service=<tu-usuario-dockerhub>/inventory-service:1.1.0

# Ver progreso
kubectl rollout status deployment/inventory-service
```

**Qué observar (Terminal 3 - progreso de la actualización):**

**Caso típico (lo que verás en la mayoría de casos):**

```bash
deployment.apps/inventory-service image updated
deployment "inventory-service" successfully rolled out
```

**Nota Pedagógica:** Los logs intermedios `"Waiting for deployment..."` **solo aparecen** si ejecutas `kubectl rollout status` **durante** el rolling update (timing muy exacto). Como los updates son rápidos (~20-30 seg), la mayoría de veces solo ves los 2 messages anteriores. No es un error, es simplemente que la actualización completó antes de que el status pudiera mostrar los pasos intermedios.

**Si quisieras ver los pasos intermedios en tiempo real, ejecutarías:**

```bash
# Opción A: En Terminal 3 durante el update (si alcanzas a tiempo)
kubectl rollout status deployment/inventory-service

# Opción B: Más confiable - monitorear ReplicaSets en Terminal 3
kubectl get rs -l app=inventory-service --watch
```

Con `--watch` verías claramente cómo el ReplicaSet viejo (v1.0.0) escala a 0 y el nuevo (v1.1.0) escala a 2 réplicas.

**Qué observar (Terminal 1 - logs del load-gen en vivo durante actualización):**

Los logs continuarán mostrando tráfico sin interrupciones (confirma CERO DOWNTIME):

```bash
[HH:MM:SS] {"service":"inventory-service","status":"UP","timestamp":...}
[HH:MM:SS] {"service":"inventory-service","status":"UP","timestamp":...}
[HH:MM:SS] {"service":"inventory-service","status":"UP","timestamp":...}
[HH:MM:SS] {"service":"inventory-service","status":"UP","timestamp":...}
```

Max 1-2 líneas con "error" es normal durante la transición.

**Qué observar (Terminal 2 - los Pods se actualizan gradualmente):**

```bash
NAME                       READY   STATUS      RESTARTS   AGE
inventory-service-xxx-abc1   1/1     Running     0          28m
inventory-service-xxx-abc2   1/1     Running     0          22m

# Momento 1: Crea Pod nuevo con v1.1.0
inventory-service-xxx-abc3   0/1     Pending     0          0s
inventory-service-xxx-abc3   0/1     ContainerCreating

# Momento 2: Nuevo Pod pasa readiness (1/1 Running)
inventory-service-xxx-abc3   1/1     Running     0          13s

# Momento 3: Elimina primer Pod viejo (abc2)
inventory-service-xxx-abc2   1/1     Terminating
inventory-service-xxx-abc2   0/1     Terminating

# Momento 4: Crea segundo Pod nuevo mientras termina el viejo
inventory-service-xxx-abc4   0/1     Pending     0          0s
inventory-service-xxx-abc4   0/1     ContainerCreating
inventory-service-xxx-abc2   0/1     Terminating

# Momento 5: Segundo Pod nuevo pasa readiness
inventory-service-xxx-abc4   1/1     Running     0          9s

# Momento 6: Elimina segundo Pod viejo (abc1)
inventory-service-xxx-abc1   1/1     Terminating
inventory-service-xxx-abc1   0/1     Terminating

# Final: 2 Pods nuevos con v1.1.0
inventory-service-xxx-abc3   1/1     Running     0          ~20s
inventory-service-xxx-abc4   1/1     Running     0          ~15s
```

**Clave:** 
- ✅ Máximo 3 Pods simultáneamente (2 viejos v1.0.0 + 1 nuevo v1.1.0, luego 1 viejo + 2 nuevos)
- ✅ Nunca hubo 0 Pods ready = **CERO DOWNTIME** garantizado
- ✅ El tráfico continuó sin interrupciones (verificado por load-gen en terminal 1)
- ✅ Los Pods viejos (hash 557df89dc9) fueron eliminados DESPUÉS de que los nuevos (hash 6fbd7dd986) pasaron readiness
- ✅ Tiempo total: ~20-30 segundos para actualizar ambas réplicas

### Paso 8.8: Verificar nueva versión en Pods

### ![linux](images/linux.png) Linux/macOS

```bash
# Obtener nombre de Pod nuevo
POD_NAME=$(kubectl get pods -l app=inventory-service -o jsonpath='{.items[0].metadata.name}')

# Consultar endpoint (ahora debería retornar "version": "v1.1.0")
kubectl exec -it $POD_NAME -- curl -s localhost:8080/v1/inventory
```

### ![win](images/windows.png) Windows

```powershell
# Obtener nombre de Pod nuevo
$POD_NAME = kubectl get pods -l app=inventory-service -o jsonpath='{.items[0].metadata.name}'

# Consultar endpoint (ahora debería retornar "version": "v1.1.0")
kubectl exec -it $POD_NAME -- curl -s localhost:8080/v1/inventory
```

**Qué observar:**

```json
{
  "service": "inventory-service",
  "status": "UP",
  "timestamp": 1728166824123,
  "version": "v1.1.0"
}
```

**Prueba importante:** Verifica que **todos los Pods** retornan v1.1.0:

### ![linux](images/linux.png) Linux/macOS

```bash
# Ver todos los Pods (deberían ser abc3 y abc4, los nuevos)
kubectl get pods -l app=inventory-service

# Para cada Pod, ejecutar curl:
kubectl exec -it inventory-service-xxx-abc3 -- curl -s localhost:8080/v1/inventory
kubectl exec -it inventory-service-xxx-abc4 -- curl -s localhost:8080/v1/inventory

# Resultado esperado en ambos Pods: "version": "v1.1.0"
```

### ![win](images/windows.png) Windows

```powershell
# Ver todos los Pods (deberían ser abc3 y abc4, los nuevos)
kubectl get pods -l app=inventory-service

# Para cada Pod, ejecutar curl:
kubectl exec -it inventory-service-xxx-abc3 -- curl -s localhost:8080/v1/inventory
kubectl exec -it inventory-service-xxx-abc4 -- curl -s localhost:8080/v1/inventory

# Resultado esperado en ambos Pods: "version": "v1.1.0"
```

**Análisis:**
- ✅ Todos los Pods retornan `"version": "v1.1.0"` = actualización completada exitosamente
- ✅ Los Pods viejos (abc1, abc2) fueron reemplazados por nuevos (abc3, abc4)
- ✅ Los campos ahora son 4 en lugar de 3 (timestamp es diferente tipo en cada consulta)

### Paso 8.9: Ver historial de despliegues

### ![linux](images/linux.png) Linux/macOS

```bash
# Ver todas las revisiones
kubectl rollout history deployment/inventory-service
```

### ![win](images/windows.png) Windows

```powershell
# Ver todas las revisiones
kubectl rollout history deployment/inventory-service
```

**Qué observar:**

```text
deployment.apps/inventory-service 
REVISION  CHANGE-CAUSE
1         <none>        ← v1.0.0 original
2         <none>        ← v1.1.0 nueva
```

**Verificación adicional - Ver qué ReplicaSet actualmente controla los Pods:**

### ![linux](images/linux.png) Linux/macOS

```bash
kubectl get rs -l app=inventory-service
```

### ![win](images/windows.png) Windows

```powershell
kubectl get rs -l app=inventory-service
```

**Qué observar:**

```text
NAME                            DESIRED   CURRENT   READY   AGE
inventory-service-xxxabc        0         0         0       30m      ← v1.0.0 (escalado a 0)
inventory-service-xxxdef        2         2         2       4m       ← v1.1.0 (activo con 2 Pods)
```

**Análisis:**
- ✅ ReplicaSet v1.0.0 (xxxabc) está escalado a 0 Pods (no eliminado, puede revertir)
- ✅ ReplicaSet v1.1.0 (xxxdef) tiene 2 Pods activos (DESIRED = CURRENT = READY = 2)
- ✅ Puedes revertir a v1.0.0 con `kubectl rollout undo deployment/inventory-service`

### Paso 8.10: Limpiar load generator

### ![linux](images/linux.png) Linux/macOS

```bash
# Eliminar el Pod de load-gen de Kubernetes
kubectl delete pod load-gen
```

### ![win](images/windows.png) Windows

```powershell
# Eliminar el Pod de load-gen de Kubernetes
kubectl delete pod load-gen
```

### Nota Pedagógica

> **Flujo real de producción (que acabas de hacer):**
> 1. Código cambia (agregamos campo `version`)
> 2. Compilas con Maven → nuevo JAR
> 3. Empaquetas con Docker → nueva imagen v1.1.0
> 4. Subes a Docker Hub → versión 1.1.0 disponible globalmente
> 5. Actualizas Kubernetes → `kubectl set image deployment/inventory-service ...`
> 6. Kubernetes automáticamente:
>    - Crea ReplicaSet nuevo con Pods nuevos (abc3, abc4)
>    - Escala gradualmente: Pods nuevos → Ready → Pods viejos → Terminating
>    - Mantiene siempre 2+ Pods listos (nunca 0)
> 7. En ~20-30 segundos: rolling update completo, sin downtime
> 8. Verificas que todos los Pods retornan `"version": "v1.1.0"` → éxito
>
> **Diferencia con Laboratorio 1.3:**
> - Lab 1.3: Desplegaste v1.0.0 inicial (primera vez)
> - Lab 2.2: Experimentaste actualización en vivo → v1.0.0 → v1.1.0 (cambio real)
>
> **Progresión pedagógica:**
> - Lab 1.1: Disponibilidad básica (sin patrones de resiliencia)
> - Lab 1.2: Resiliencia EN CÓDIGO (@Retry, @CircuitBreaker, etc.)
> - Lab 1.3: Empaquetamiento en Docker (v1.0.0)
> - **Lab 2.2: Orquestación + Rolling Updates en vivo** ← Ahora (v1.0.0 → v1.1.0)
> - Lab 2.3: Auto-scaling horizontal con HPA (→ futura)

---

## Paso 9: Rollback a versión anterior

**Qué hace:** Revertir a versión anterior si actualización tiene problemas.

**Por qué:** K8s mantiene historial de despliegues para recuperación rápida.

### Deshacer última actualización

### ![linux](images/linux.png) Linux/macOS

```bash
# Revertir a revisión anterior
kubectl rollout undo deployment/inventory-service

# Verificar reversión
kubectl rollout history deployment/inventory-service

# Ver Pods actualizado
kubectl get pods -l app=inventory-service
```

### ![win](images/windows.png) Windows

```powershell
# Revertir a revisión anterior
kubectl rollout undo deployment/inventory-service

# Verificar reversión
kubectl rollout history deployment/inventory-service

# Ver Pods actualizado
kubectl get pods -l app=inventory-service
```

**Qué observar:**

**Terminal 3 - Comando de rollback:**

```bash
deployment.apps/inventory-service rolled back
```

**Verificar el historial después del rollback:**

```bash
kubectl rollout history deployment/inventory-service
```

**Output esperado:**

```text
deployment.apps/inventory-service 
REVISION  CHANGE-CAUSE
1         <none>
2         <none>        ← Revisión anterior (a la que rollback)
3         <none>        ← Revisión que acabas de deshacer
```

**Nota:** Después del rollback, la revisión anterior (2) vuelve a ser la activa. Los números son consecutivos según cuántas actualizaciones hayas hecho en el Deployment.

**Terminal 2 - Observar los Pods restaurados:**

En la Terminal 2 que tiene `--watch` ejecutándose, verás de nuevo:

```bash
inventory-service-xxx-abc3   1/1     Terminating   0        ~10m
inventory-service-xxx-abc4   1/1     Terminating   0        ~8m

# Nuevos Pods con versión anterior se crean
inventory-service-xxx-abc1   0/1     Pending       0        1s
inventory-service-xxx-abc2   0/1     Pending       0        1s

# Se restaura a v1.0.0
inventory-service-xxx-abc1   1/1     Running       0        8s
inventory-service-xxx-abc2   1/1     Running       0        6s
```

**Análisis:**
- ✅ Rollback completó exitosamente
- ✅ Los Pods de v1.1.0 (abc3, abc4) fueron reemplazados por Pods de v1.0.0 (abc1, abc2)
- ✅ Puedes verificar la versión con: `kubectl exec -it <pod-name> -- curl -s localhost:8080/v1/inventory` (debería retornar `"version": "v1.1.0"` si es v1.1.0 o el campo ausente si retorna a v1.0.0)

---

## Guía de Troubleshooting

### Problema 1: pods en `imagepullbackoff`

**Síntoma:** `kubectl get pods` muestra status `ImagePullBackOff`

**Causa común:** Docker Hub no encuentra la imagen (typo en nombre o no fue subida)

**Solución:**

```bash
# Verificar que la imagen fue subida correctamente a Docker Hub
docker push <tu-usuario-dockerhub>/inventory-service:1.0.0

# Si el push es exitoso, eliminar Pods para que K8s re-descargue
kubectl delete pods -l app=inventory-service

# Ver logs del Pod para más detalles
kubectl logs <pod-name>
```

**Checklist:**
- ✅ ¿Ejecutaste `docker login` antes de `docker push`?
- ✅ ¿El nombre en `docker build -t` es `<tu-usuario-dockerhub>/inventory-service:1.0.0`?
- ✅ ¿El nombre en deployment YAML coincide exactamente con lo que subiste?
- ✅ ¿La imagen es pública en Docker Hub (no privada)?

---

### Problema 2: pods en `crashloopbackoff`

**Síntoma:** Pod reinicia constantemente

**Causa común:** Error en aplicación o startupProbe muy agresivo

**Solución:**

```bash
# Ver logs
kubectl logs -f <pod-name>

# Describe pod para ver eventos
kubectl describe pod <pod-name>

# Aumentar failureThreshold o initialDelaySeconds en startupProbe
```

---

### Problema 3: Rolling Update se queda atascado

**Síntoma:** `kubectl rollout status` no completa

**Causa común:** Pod nuevo no pasa readiness probe

**Solución:**

```bash
# Ver descripción de Pod
kubectl describe pod <pod-name>

# Aumentar failureThreshold en readinessProbe si es muy estricto
```

---

## Entregable

**Debes proporcionar evidencia (capturas de pantalla o logs) de:**

### 1. Despliegue exitoso (ambos servicios)

```bash
kubectl get pods
kubectl get svc
```

**Captura:** Mostrando:
- ✅ `catalog-deployment-xxx` en `Running` y `1/1 Ready`
- ✅ `inventory-service-xxx` (2 réplicas) en `Running` y `1/1 Ready`
- ✅ `catalog-service` y `inventory-service` en `ClusterIP`

### 2. Health Probes funcionando

```bash
kubectl describe pod <inventory-pod-name>
```

**Captura:** Mostrando StartupProbe, ReadinessProbe, LivenessProbe correctamente configurados

### 3. Autocuración

```bash
kubectl get events --sort-by='.metadata.creationTimestamp'
```

**Captura:** Eventos mostrando:
- Eliminación manual de Pod
- Creación automática de reemplazo

### 4. Rolling Update sin downtime

```bash
kubectl rollout status deployment/inventory-service
```

**Captura:** Showing `successfully rolled out` durante actualización

---

## Resumen de conceptos

| Concepto | Qué hace | Por qué importante |
|----------|----------|-------------------|
| **Deployment** | Define cuántas réplicas, qué imagen, strategy | Orquestación automática |
| **ReplicaSet** | Mantiene N réplicas activas | Tolerancia a fallos |
| **Service** | Expone Pods en red K8s | Load balancing automático |
| **StartupProbe** (Health Check de arranque) | Espera a que contenedor inicie | Evita prematuros restart |
| **ReadinessProbe** (Health Check de preparación) | ¿Pod listo para tráfico? | Evita rutas a Pods no-ready |
| **LivenessProbe** (Health Check de vida) | ¿Pod sigue respondiendo? | Autocuración de bloqueos |
| **RollingUpdate** | maxSurge/maxUnavailable | Cero-downtime updates |

---

**Fin de Laboratorio 2.2**

Felicidades: Ahora comprendes orquestación Kubernetes con resiliencia infraestructural.  
Continúa con [Laboratorio 2.3](./laboratorio-clase-2-3.md) para escalar automáticamente con HPA.
