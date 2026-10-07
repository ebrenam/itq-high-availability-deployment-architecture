# Anexo: Versionamiento en Java/Maven/Docker

## Contexto

Cuando actualizas una aplicación en Kubernetes (rolling update), hay **3 niveles de versionamiento** que funcionan de manera independiente pero relacionada:

1. **Maven/Java (`pom.xml`)**: Versión del proyecto fuente
2. **Código Java**: Versión de negocio (puede estar hardcoded o en variables)
3. **Docker Image**: Versión de la imagen empaquetada para distribución

Estos NO necesariamente deben ser iguales, pero es buena práctica mantenerlos coherentes.

---

## Los 3 niveles de versionamiento

### 1. Maven/Java: `pom.xml` (Control de Fuente)

**Archivo:** `pom.xml`

```xml
<project>
    <modelVersion>4.0.0</modelVersion>
    <groupId>com.ecom</groupId>
    <artifactId>inventory-service</artifactId>
    <version>1.0.0-SNAPSHOT</version>  ← AQUÍ
    ...
</project>
```

**Características:**
- Controlado por el desarrollador manualmente
- Se usa para compilar el JAR: `mvn clean package` genera `inventory-service-1.0.0-SNAPSHOT.jar`
- Parte del control de versiones (Git)
- Puede ser `1.0.0-SNAPSHOT` (desarrollo) o `1.0.0` (release)

**¿Cuándo cambia?**
- El dev decide cambiar el número (normalmente en release)
- No cambia automáticamente

---

### 2. Código Java: Retorno de versión en el endpoint

**Archivo:** `src/main/java/com/ecom/inventory/InventoryResource.java`

```java
@Path("/v1/inventory")
public class InventoryResource {

    @GET
    @Produces(MediaType.APPLICATION_JSON)
    public InventoryStatus getStatus() {
        return new InventoryStatus("inventory-service", "UP", 
                                   System.currentTimeMillis(), 
                                   "v1.1.0");  ← AQUÍ (hardcoded)
    }

    public record InventoryStatus(String service, String status, 
                                  long timestamp, String version) {}
}
```

**Características:**
- Es lo que retorna el API cuando se consulta `/v1/inventory`
- Puede estar **hardcoded** (como arriba) o leer desde `application.properties`
- Es para **propósitos de demostración** en este laboratorio
- En producción, preferirías leer desde variables de entorno o archivos de config

**¿Cuándo cambia?**
- El dev lo cambia manualmente en el código
- Después de cambiar, debe recompilar con Maven

---

### 3. Docker Image: Tag de la imagen

**Comando de build:**

```bash
docker build -t <usuario>/inventory-service:1.1.0 .
                                             ↑
                                        TAG aquí
```

**Características:**
- **Tú** decides qué tag asignar
- Es independiente de `pom.xml`
- Es lo que Kubernetes usa para descargar la imagen: `imagePullPolicy: Always`
- Se publica en Docker Hub: `docker push <usuario>/inventory-service:1.1.0`

**¿Cuándo cambia?**
- El dev decide al ejecutar `docker build -t <tag>`
- Es lo que finalmente importa para Kubernetes

---

## Ejemplo: Actualización v1.0.0 → v1.1.0

### Paso 1: Cambiar código Java

```java
// ANTES (v1.0.0)
return new InventoryStatus("inventory-service", "UP", 
                           System.currentTimeMillis());

// DESPUÉS (v1.1.0)
return new InventoryStatus("inventory-service", "UP", 
                           System.currentTimeMillis(), 
                           "v1.1.0");  ← Agregué campo version
```

### Paso 2: Compilar con Maven

```bash
mvn clean package -DskipTests
```

**Output:**

```bash
[INFO] Building inventory-service 1.0.0-SNAPSHOT
[INFO] BUILD SUCCESS
```

**Nota:** El `pom.xml` sigue diciendo `1.0.0-SNAPSHOT` (NO cambió). El JAR compilado contiene el código nuevo (con "v1.1.0" hardcoded).

**Archivo generado:** `target/inventory-service-1.0.0-SNAPSHOT.jar` (nombre del JAR según `pom.xml`)

### Paso 3: Empaquetar con Docker

```bash
docker build -t <usuario>/inventory-service:1.1.0 .
```

**Qué pasa:**
- Docker incluye el JAR compilado (que contiene "v1.1.0" hardcoded)
- Lo empaqueta en una imagen de runtime
- **Tú asignas el tag `1.1.0`** (independiente de `pom.xml`)

### Paso 4: Subir a Docker Hub

```bash
docker push <usuario>/inventory-service:1.1.0
```

### Paso 5: Actualizar Kubernetes

```bash
kubectl set image deployment/inventory-service \
  inventory-service=<usuario>/inventory-service:1.1.0
```

Kubernetes tira la imagen `1.1.0` y ejecuta Pods nuevos con ese código.

---

## Tabla resumen: Qué cambia en cada nivel

| Nivel | Qué es | Cambio | Ejemplo |
|-------|--------|--------|---------|
| **Maven** | `pom.xml` | Manual | `1.0.0-SNAPSHOT` → `1.1.0` |
| **Java** | Código fuente | Manual en archivo `.java` | `"v1.0.0"` → `"v1.1.0"` hardcoded |
| **Docker** | Tag de imagen | Manual en comando `docker build -t` | `1.0.0` → `1.1.0` |

---

## Flujo completo en producción

```text
┌─────────────────────────────────────────────────────┐
│ 1. DEV: Cambio de código (new feature)              │
└─────────────────────┬───────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────┐
│ 2. DEV: Edita pom.xml (1.0.0 → 1.1.0)               │
│    (Opcional, pero buena práctica)                  │
└─────────────────────┬───────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────┐
│ 3. CI/CD: mvn clean package                         │
│    Genera JAR 1.1.0                                 │
└─────────────────────┬───────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────┐
│ 4. CI/CD: docker build -t app:1.1.0                 │
│    Empaqueta JAR en imagen                          │
└─────────────────────┬───────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────┐
│ 5. CI/CD: docker push app:1.1.0                     │
│    Sube a Docker Hub/Registry                       │
└─────────────────────┬───────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────┐
│ 6. K8s: kubectl set image deployment/app app:1.1.0  │
│    Rolling update con 0 downtime                    │
└─────────────────────────────────────────────────────┘
```

En este laboratorio **tú haces todo manualmente** para entender cada paso.

---

## En este laboratorio (Paso 8.2)

### ¿Por qué `pom.xml` sigue siendo `1.0.0-SNAPSHOT`?

Porque:

1. **Es intencional.** Queremos demostrar que los 3 niveles son independientes
2. **En producción:** Aumentarías `pom.xml` → Maven automáticamente generaría JAR versión nueva
3. **En este laboratorio:** Simplificamos: solo cambiamos código Java (hardcoded "v1.1.0") y Docker tag

### Flujo en este laboratorio

```text
Cambio código Java
     ↓
mvn clean package
     ↓
JAR compilado contiene "v1.1.0"
(pom.xml sigue siendo 1.0.0-SNAPSHOT)
     ↓
docker build -t usuario/inventory-service:1.1.0
     ↓
docker push
     ↓
kubectl set image ... :1.1.0
     ↓
✅ Rolling update con nueva versión
```

---

## Mejor práctica: Coherencia

En una situación real, preferirías:

**Opción A: Todo igual**
```
pom.xml: 1.1.0
Código Java: leer desde application.properties (que lee de pom.xml)
Docker tag: 1.1.0
```

**Opción B: Separado pero documentado**
```
pom.xml: 1.1.0 (control de fuente)
Código Java: 1.1.0 (leído desde config)
Docker tag: 1.1.0 (mismo que pom.xml)
```

**Lo que nunca hagas:**
```
pom.xml: 1.0.0
Código Java: "v2.0.0"
Docker tag: 3.0.0
← Confuso, nadie sabe qué versión es cuál
```

---

## Conclusión

- **Maven (`pom.xml`)**: Control de fuente, decisión del dev
- **Código Java**: Lógica de negocio, decisión del dev
- **Docker tag**: Distribución, decisión del dev

Los 3 son **independientes pero deben estar coordinados**.

En este laboratorio, lo importante es que **entiendas que son 3 cosas diferentes**, no que sean idénticas.
