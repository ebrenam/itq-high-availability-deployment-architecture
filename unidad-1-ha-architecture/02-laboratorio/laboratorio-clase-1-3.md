# Laboratorio de la clase 1.3: De Docker a Kubernetes Local

## Objetivo del laboratorio

Empaquetar el `catalog-service` resiliente del laboratorio 1.2 en una imagen Docker y desplegarlo en un clúster Kubernetes local. Entenderás la diferencia entre ejecutar contenedores imperativamente (`docker run`) y declararlos en Kubernetes (YAML). Este laboratorio cierra el ciclo de la Unidad 1 introduciendo el orquestador que profundizarás en Unidad 2.

**Regla de continuidad:** Este laboratorio requiere que hayas completado exitosamente [Laboratorio 1.1](./laboratorio-clase-1-1.md) y [Laboratorio 1.2](./laboratorio-clase-1-2.md). Si comienzas aquí directamente, `CatalogResource.java` no tendrá los patrones de resiliencia (`@Timeout`, `@Retry`, `@CircuitBreaker`, `@Fallback`) y el despliegue no validará el impacto de esos patrones.

## Prerequisitos y stack tecnológico

Además de los prerequisitos de 1.1 y 1.2, necesitas:

- **Kubernetes local:** Minikube (v1.30+), Kind (v0.20+) o Docker Desktop con Kubernetes.
  - Ver [Anexo: Instalar Kubernetes Local](../01-clase/anexo-kubernetes-local.md) para instrucciones de instalación en tu sistema operativo.
- **kubectl** configurado e interconectado con tu clúster local.
  - Ver [Anexo: Instalar kubectl](../01-clase/anexo-instalar-kubectl.md) para instrucciones de instalación en tu sistema operativo.
- **Docker Engine** instalado y funcionando en tu máquina.
- **Cuenta en Docker Hub** (gratuita): Para subir tus imágenes Docker.
  - Crear cuenta en: https://hub.docker.com/signup

> **NOTA PEDAGÓGICA**
>
> En este laboratorio aprendes algunos conceptos de Kubernetes para entender que existe como alternativa a Docker. Los conceptos (Deployment, Service, Labels) se profundizarán en Unidad 2.

## Punto de partida

Trabaja desde `02-laboratorio/proyecto-base-unidad-01/catalog-service` con los patrones implementados en `CatalogResource.java` (laboratorio 1.2).

**Archivos YAML:** En la carpeta `k8s/` ya existen los manifiestos que usarás y que editarás:

- `k8s/01-deployment.yaml` → Actualizarás el campo `image` con tu usuario de Docker Hub
- `k8s/02-service.yaml` → Define cómo se accede a la aplicación desde la red (sin cambios necesarios)

Estos archivos son reutilizables y servirán como base para Unidad 2, donde agregaremos múltiples réplicas, escalamiento automático y configuración externa.

---

## Paso 1: Preparar Kubernetes Local

**Verifica que tu clúster está operativo:**

```bash
# Verificar kubectl y clúster
kubectl cluster-info
kubectl get nodes

# Opcional: Ver dashboard de Minikube
minikube dashboard
```

Si no tienes Kubernetes instalado, sigue las instrucciones en el [Anexo: Instalar Kubernetes Local](../01-clase/anexo-kubernetes-local.md) según tu sistema operativo.

---

## Paso 2: Construir la imagen Docker y subirla a Docker Hub

### 2.1: Compilar y construir imagen

Compila y empaqueta tu código:

```bash
cd unidad-1-ha-architecture/02-laboratorio/proyecto-base-unidad-01/catalog-service
./mvnw clean package -DskipTests
```

Constituye la imagen Docker con tu usuario de Docker Hub (reemplaza `<TU_USUARIO>`):

```bash
docker build -t <TU_USUARIO>/catalog-service:1.0.0 .
```

**Ejemplo si tu usuario es `john-doe`:**

```bash
docker build -t john-doe/catalog-service:1.0.0 .
```

### 2.2: Subir imagen a Docker Hub

Primero, autentica tu cliente Docker con Docker Hub:

```bash
docker login
# Ingresa tu usuario y contraseña de Docker Hub
```

Ahora sube la imagen:

```bash
docker push <TU_USUARIO>/catalog-service:1.0.0
```

**Verificar en Docker Hub:**

- Ve a `https://hub.docker.com/r/<TU_USUARIO>/catalog-service`
- Deberías ver el tag `1.0.0` disponible

### 2.3: Verificar que descargues desde Docker Hub

Elimina la imagen local y verifica que puedes descargarla de hub:

```bash
docker image rm <TU_USUARIO>/catalog-service:1.0.0
```

Ahora descárgala desde hub:

```bash
docker pull <TU_USUARIO>/catalog-service:1.0.0
# Deberías ver: "Status: Downloaded newer image for <TU_USUARIO>/catalog-service:1.0.0"
```

---

## Paso 3: Despliegue desde Docker Hub usando archivos YAML

Ahora desplegarás tu aplicación en Kubernetes **descargándola desde tu repositorio en Docker Hub**.

### 3.1: Revisar archivos YAML en k8s/

Verifica que los archivos existen:

```bash
ls -la k8s/
# Deberías ver: 01-deployment.yaml, 02-service.yaml

cat k8s/01-deployment.yaml
cat k8s/02-service.yaml
```

### 3.2: Actualizar nombre de imagen en Deployment

Abre `k8s/01-deployment.yaml` y busca la línea:

```yaml
image: catalog-service:1.0.0
```

Cámbiala a tu imagen en Docker Hub:

```yaml
image: <TU_USUARIO>/catalog-service:1.0.0
```

**Ejemplo si tu usuario es `john-doe`:**

```yaml
image: john-doe/catalog-service:1.0.0
```

**Nota:** El campo `imagePullPolicy: IfNotPresent` dice que Kubernetes descarga la imagen de Docker Hub si no la encuentra localmente. Este es el comportamiento típico en producción.

### 3.3: Archivo 02-service.yaml (sin cambios)

No necesita modificación. Solo define cómo acceder al servicio internamente en el clúster.

**Contenido esperado:**

```yaml
apiVersion: v1
kind: Service
metadata:
  name: catalog-service
  labels:
    app: catalog-service
spec:
  type: ClusterIP
  selector:
    app: catalog-service
  ports:
  - port: 8080
    targetPort: 8080
    protocol: TCP
    name: http
```

### 3.4: Health Checks en el Deployment

**Importante:** Observa que el Deployment ya incluye `readinessProbe` y `livenessProbe`:

```yaml
readinessProbe:
  httpGet:
    path: /ready
    port: 8080
  initialDelaySeconds: 5
  periodSeconds: 5
  timeoutSeconds: 2
  failureThreshold: 2

livenessProbe:
  httpGet:
    path: /live
    port: 8080
  initialDelaySeconds: 10
  periodSeconds: 10
  timeoutSeconds: 2
  failureThreshold: 3
```

**¿De dónde vienen estos endpoints?**

- Validaste manualmente en [Lab 1.1 Paso 2](./laboratorio-clase-1-1.md#paso-2-revisar-salud): `curl http://localhost:8080/ready` y `curl http://localhost:8080/live`
- Ahora, en Lab 1.3, **Kubernetes valida automáticamente** estos endpoints cada 5-10 segundos
- Si `/ready` falla, Kubernetes remueve el pod del Service (no recibe tráfico)
- Si `/live` falla, Kubernetes reinicia el contenedor

> **NOTA PEDAGÓGICA**
>
> La transición de "validar manualmente" (Lab 1.1) a "validar automáticamente" (Lab 1.3) es clave. Sin health checks, Kubernetes no sabría que un pod está fallando.

### 3.5: Aplicar manifiestos en Kubernetes

Ahora usa los archivos YAML para desplegar. Kubernetes automáticamente validará los health checks:

```bash
# Aplicar Deployment (incluye probes de health checks)
kubectl apply -f k8s/01-deployment.yaml

# Aplicar Service
kubectl apply -f k8s/02-service.yaml
```

> **NOTA PEDAGÓGICA**
>
> Observa el flujo:
> - **Deployment** (`01-deployment.yaml`): Declara "quiero 1 réplica con health checks" (vs. `docker run` imperativo)
> - **Health Checks en Lab 1.1**: Validaste manualmente que `/ready` y `/live` existen
> - **Health Checks en Lab 1.3**: Kubernetes los valida automáticamente cada 5-10 segundos
> - **Service**: Abstracción de red declarativa (vs. `docker port-forward` manual)
> - **imagePullPolicy**: Kubernetes descargará tu imagen desde Docker Hub automáticamente

En Unidad 2, expandirás este Deployment con: múltiples réplicas, escalamiento automático (HPA), configuración externa (ConfigMaps/Secrets).

### 3.6: Verificar despliegue

Confirma que el Deployment y Service están operativos:

```bash
# Verificar que el Deployment existe
kubectl get deployment catalog-service

# Verificar que el Pod está corriendo
kubectl get pods -l app=catalog-service

# Verificar que el Service está disponible
kubectl get service catalog-service
```

Output esperado:

```bash
NAME                  READY   UP-TO-DATE   AVAILABLE   AGE
catalog-service       1/1     1            1           15s

NAME                        READY   STATUS    RESTARTS   AGE
catalog-service-xyz123-abc  1/1     Running   0          15s

NAME                TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
catalog-service     ClusterIP   10.96.123.45    <none>        8080/TCP  15s
```

**Nota:** Si ves `READY 0/1`, es posible que los health checks estén todavía validándose. Espera 10-15 segundos y verifica nuevamente.

---

## Paso 4: Validar funcionamiento

### 4.1: Acceder al servicio

Accede a tu servicio usando `port-forward`:

```bash
kubectl port-forward svc/catalog-service 8080:8080
```

En otra terminal, prueba los endpoints:

```bash
# Endpoint principal
curl -s http://localhost:8080/v1/products | jq .

# Health checks (aprendiste en Lab 1.1)
curl -s http://localhost:8080/health | jq .
curl -s http://localhost:8080/ready | jq .
curl -s http://localhost:8080/live | jq .
```

Deberías ver respuestas JSON con `{"status":"SUCCESS", ...}` o `{"status":"DEGRADED_CACHE", ...}` (tal como viste en Lab 1.2).

### 4.2: Verificar que la imagen viene desde Docker Hub y Health Checks funciona

Confirma dos cosas:

**1. Kubernetes descargó tu imagen desde Docker Hub:**

```bash
# Ver eventos recientes (busca descarga de imagen)
kubectl describe pod <nombre-del-pod>

# Deberías ver algo como:
# Events:
#   Type    Reason     Age    Message
#   ----    ------     ---    -------
#   Normal  Pulling    2m10s  Pulling image "<TU_USUARIO>/catalog-service:1.0.0"
#   Normal  Pulled     2m05s  Successfully pulled image "<TU_USUARIO>/catalog-service:1.0.0"
#   Normal  Created    2m05s  Created container catalog-service
#   Normal  Started    2m05s  Started container catalog-service
```

**2. Kubernetes está validando automáticamente los health checks:**

En los mismos eventos, busca líneas como:

```bash
Readiness probe succeeded
Liveness probe succeeded
```

Esto demuestra que:
- ✅ Kubernetes descargó tu imagen desde Docker Hub
- ✅ El contenedor está corriendo
- ✅ Los endpoints `/ready` y `/live` responden correctamente
- ✅ Kubernetes hace el mismo trabajo que hiciste manualmente en Lab 1.1, pero **automáticamente**

**¿Qué está ocurriendo?**

| Docker (`Lab 1.2`) | Kubernetes (`Lab 1.3`) | Observación |
|---|---|---|
| `docker run catalog-service:1.0.0` | `kubectl apply -f deployment.yaml` | Despliegue declarativo vs. imperativo |
| `docker ps` | `kubectl get pods` | Ver contenedores activos |
| `docker logs <container>` | `kubectl logs <pod-name>` | Ver salida de aplicación |
| `docker exec <container> curl ...` | `kubectl exec <pod-name> -- curl ...` | Acceder dentro del contenedor |

La aplicación es **exactamente la misma**. Lo que cambió es cómo la orquestas.

---

## Paso 5: Limpieza y conclusión

Cuando termines de experimentar, limpia los recursos:

```bash
kubectl delete deployment catalog-service
kubectl delete service catalog-service
```

---

## Conclusión y próximos pasos

Has completado tres laboratorios que forman la base de Unidad 1:

| Laboratorio | Foco | Evidencia |
|---|---|---|
| **Lab 1.1** | Medir baseline (sin resiliencia) | `availability-baseline.txt` |
| **Lab 1.2** | Implementar resiliencia de software | Code con `@Timeout`, `@Retry`, `@CircuitBreaker`, `@Fallback` |
| **Lab 1.3** | Empaquetar y orquestar con Kubernetes | `catalog-service:1.0.0` desplegado localmente |

### Conceptos que seguirán evolucionando en unidad 2

✅ **Ya conoces:**
- Resiliencia de software (patrones en código Java con `@Timeout`, `@Retry`, `@CircuitBreaker`, `@Fallback`)
- Orquestación básica (Deployment, Service, Labels, Selectors)
- Health checks en Kubernetes (readinessProbe, livenessProbe)
- Descarga automática de imágenes desde Docker Hub

🔎 **En Unidad 2 aprenderás:**
- Múltiples réplicas y escalamiento automático (HPA)
- Configuración externa (ConfigMaps, Secrets)
- Distribución multi-AZ y topologySpreadConstraints
- Estrategias avanzadas de actualización (RollingUpdate, Blue-Green)
- Observabilidad y métricas en Kubernetes

### El aprendizaje es incremental

No es coincidencia que Lab 1.3 sea simple. **Vas a reutilizar todo esto en Unidad 2:**

```
Lab 1.3: 1 réplica, ClusterIP, health checks básicos
  ↓ (Reutiliza imagen + manifiestos)
Lab 2.1: Agregar múltiples réplicas, topologySpreadConstraints, ajustar probes
  ↓ (Reutiliza deployment de Lab 2.1)
Lab 2.2: Agregar ConfigMaps, Secrets, HPA (escalamiento automático)
  ↓ (Reutiliza todos los patrones)
Lab 2.3 (OPT): Crear nuevo microservicio aplicando todo
```

**La meta es que entiendas cada concepto antes de agregarlo.**

---

## Criterios de aceptación

Para completar Lab 1.3, el estudiante debe demostrar:

### Evidencia mínima

1. **Imagen Construida y Publicada en Docker Hub:**
   ```bash
   docker build -t <TU_USUARIO>/catalog-service:1.0.0 .
   docker push <TU_USUARIO>/catalog-service:1.0.0
   ```
   - Captura de `docker push` mostrando carga exitosa
   - Acceso a `https://hub.docker.com/r/<TU_USUARIO>/catalog-service` mostrando tag `1.0.0`

2. **YAML Actualizado con tu Repositorio:**
   ```bash
   cat k8s/01-deployment.yaml | grep "image:"
   # Debe mostrar: image: <TU_USUARIO>/catalog-service:1.0.0
   ```
   - Captura del contenido de `k8s/01-deployment.yaml` mostrando tu usuario en el campo `image`

3. **Deployment en Kubernetes con Health Checks Automáticos:**
   ```bash
   kubectl apply -f k8s/01-deployment.yaml
   kubectl apply -f k8s/02-service.yaml
   kubectl describe pod <nombre-del-pod>
   # Buscar en Events: "Pulling image" + "Readiness probe succeeded" + "Liveness probe succeeded"
   ```
   - Captura mostrando 1 Pod en estado `Running` y `READY 1/1`
   - Captura de eventos (`kubectl describe pod`) demostrando que:
     - Kubernetes **descargó** la imagen desde Docker Hub
     - Los health checks `/ready` y `/live` están siendo validados automáticamente (líneas como "Readiness probe succeeded" y "Liveness probe succeeded")

4. **Validación de Funcionamiento del Servicio:**
   ```bash
   kubectl port-forward svc/catalog-service 8080:8080
   curl http://localhost:8080/v1/products
   curl http://localhost:8080/health
   curl http://localhost:8080/ready
   curl http://localhost:8080/live
   ```
   - Captura mostrando respuestas JSON con `status: SUCCESS` o `status: DEGRADED_CACHE` en `/v1/products`
   - Capturas de `/health`, `/ready`, `/live` mostrando `status: UP`

### Explicación técnica integrada (máximo 200 palabras)

Explica el flujo completo que seguiste:

1. **Build local:** Compilaste con Maven y Docker, generando `<TU_USUARIO>/catalog-service:1.0.0`
2. **Push a Docker Hub:** Subiste la imagen a tu repositorio público, haciéndola descargable desde cualquier computadora
3. **Declaración en Kubernetes:** El archivo `k8s/01-deployment.yaml` declara:
   - Qué imagen usar (desde Docker Hub)
   - Qué health checks ejecutar (`readinessProbe`, `livenessProbe`)
4. **Descarga automática:** Cuando ejecutaste `kubectl apply`, Kubernetes descargó la imagen desde Docker Hub si no la encontraba localmente
5. **Health checks automáticos:** Kubernetes valida automáticamente:
   - `/ready`: ¿Está listo para recibir tráfico? (cada 5 segundos)
   - `/live`: ¿Está vivo el proceso? (cada 10 segundos)

**Transición pedagógica importante:**
- **Lab 1.1:** Validaste manualmente que `/health`, `/ready`, `/live` existen (con `curl`)
- **Lab 1.3:** Declaras en el YAML que Kubernetes debe validarlos automáticamente

**¿Por qué es importante?**
- Sin health checks, Kubernetes no sabría que un pod está fallando
- En producción, Kubernetes reemplaza automáticamente pods dañados
- Este es el modelo estándar en CI/CD pipelines profesionales

Este es el flujo: Build local → Push a registry → Deploy con declaración de health checks → Kubernetes valida automáticamente.

---

## Reflexión final

En Unidad 1 aprendiste:
- **Teoría:** Conceptos de disponibilidad, SLAs, patrones de resiliencia
- **Software:** Implementar `@Timeout`, `@Retry`, `@CircuitBreaker`, `@Fallback` en Java
- **Infraestructura:** Orquestar con Kubernetes (el paso inicial)
- **DevOps:** Build local → Push a registry → Deploy desde registry (flujo CI/CD)

En Unidad 2, profundizarás en cada aspecto. Este lab cubre lo mínimo para que entiendas que Kubernetes existe, que las imágenes se comparten via Docker Hub, y que el despliegue es reproducible desde una descripción YAML.

**El modelo que aprendiste aquí es el usado en empresas reales:** tus imágenes viven en Docker Hub (o Quay, ECR, GCR, etc.), y tus manifiestos YAML declaran cuál versión desplegar. Cambiar versión es tan simple como editar una línea en el YAML.

**Adelante con Unidad 2. ¡Lo hiciste! 🎉**
