# Guía para Estudiantes en Windows

Esta guía está diseñada específicamente para ejecutar el proyecto en **Windows 10/11 con Docker Desktop**.

---

## 🪟 Prerrequisitos para Windows

### 1. Instalar Java 25

**Opción A: Temurin (Eclipse Adoptium) - Recomendado**

1. Descargar desde: https://adoptium.net/temurin/releases/?version=25
2. Seleccionar: **Windows x64**, **JDK**, **25**
3. Ejecutar el instalador (.msi)
4. Verificar instalación:

```powershell
java -version
```

Debe mostrar: `openjdk version "25"`

**Opción B: Usando Chocolatey**

Si tienes Chocolatey instalado:

```powershell
choco install temurin25
```

### 2. Instalar Docker Desktop

1. Descargar desde: https://www.docker.com/products/docker-desktop/
2. Ejecutar el instalador
3. Reiniciar Windows si lo solicita
4. Abrir Docker Desktop
5. Verificar en PowerShell:

```powershell
docker --version
docker-compose --version
```

### 3. Git para Windows (opcional)

Si aún no lo tienes:

```powershell
# Con Chocolatey
choco install git

# O descargar desde:
# https://git-scm.com/download/win
```

---

## 🚀 Ejecución del Proyecto en Windows

### Opción 1: Modo Desarrollo Local (Más simple)

Abre **PowerShell** o **CMD** en el directorio del proyecto:

```powershell
# Navegar al proyecto
cd proyecto-base\catalog-service

# Ejecutar en modo desarrollo
.\mvnw.cmd quarkus:dev
```

**Nota:** En Windows usa `mvnw.cmd` en lugar de `./mvnw`

Probar en otra terminal:

```powershell
curl http://localhost:8080/v1/products
curl http://localhost:8080/health
```

Si `curl` no está disponible, usa el navegador:
- http://localhost:8080/v1/products
- http://localhost:8080/health

### Opción 2: Docker Compose (Recomendado para Windows)

**Esta es la forma más fácil de ejecutar el proyecto sin Kubernetes.**

```powershell
# Navegar al directorio proyecto-base
cd proyecto-base

# Iniciar servicio con Docker Compose
docker-compose up -d

# Ver logs
docker-compose logs -f catalog-service

# Verificar estado
docker-compose ps
```

Probar el servicio:

```powershell
curl http://localhost:8080/v1/products
# O abrir en navegador: http://localhost:8080/v1/products
```

Detener el servicio:

```powershell
docker-compose down
```

### Opción 3: Kubernetes en Docker Desktop (Avanzado)

**Solo si quieres practicar con Kubernetes:**

#### Paso 1: Habilitar Kubernetes en Docker Desktop

1. Abrir Docker Desktop
2. Ir a **Settings** (⚙️)
3. Seleccionar **Kubernetes**
4. Marcar **Enable Kubernetes**
5. Clic en **Apply & Restart**
6. Esperar a que el ícono de Kubernetes esté verde

#### Paso 2: Verificar que kubectl funciona

```powershell
kubectl version --client
kubectl cluster-info
```

#### Paso 3: Construir y desplegar

```powershell
# Navegar al servicio
cd proyecto-base\catalog-service

# Compilar el proyecto
.\mvnw.cmd clean package -DskipTests

# Construir imagen Docker
docker build -t catalog-service:1.0.0 .

# Desplegar en Kubernetes
kubectl apply -f k8s\01-deployment.yaml
kubectl apply -f k8s\02-service.yaml

# Verificar pods
kubectl get pods -l app=catalog-service

# Ver servicio
kubectl get svc catalog-service-lb
```

---

## 🔧 Comandos Útiles en Windows

### PowerShell

```powershell
# Compilar proyecto
.\mvnw.cmd clean package

# Ejecutar en modo dev
.\mvnw.cmd quarkus:dev

# Listar contenedores Docker
docker ps

# Ver logs de Docker Compose
docker-compose logs -f

# Reconstruir imagen
docker-compose build

# Eliminar todo (Docker Compose)
docker-compose down -v

# Ver logs de Kubernetes
kubectl logs -l app=catalog-service --tail=50
```

### CMD (Command Prompt)

Si prefieres CMD en lugar de PowerShell:

```cmd
REM Compilar
mvnw.cmd clean package

REM Ejecutar dev
mvnw.cmd quarkus:dev

REM Docker Compose
docker-compose up -d
docker-compose down
```

---

## 🐛 Troubleshooting en Windows

### Problema: "mvnw no se reconoce"

**Solución:** Usa `mvnw.cmd` en lugar de `./mvnw`

```powershell
# ❌ Incorrecto en Windows
./mvnw quarkus:dev

# ✅ Correcto en Windows
.\mvnw.cmd quarkus:dev
# o simplemente
mvnw.cmd quarkus:dev
```

### Problema: "curl no está disponible"

**Solución 1:** Instalar curl

```powershell
# Windows 10 1803+ ya incluye curl
# Si no funciona, instalar con Chocolatey:
choco install curl
```

**Solución 2:** Usar PowerShell alternativo

```powershell
# Alternativa a curl
Invoke-WebRequest -Uri http://localhost:8080/v1/products
```

**Solución 3:** Usar el navegador
- Abrir: http://localhost:8080/v1/products

### Problema: Docker Desktop no inicia

**Soluciones:**

1. Habilitar virtualización en BIOS
2. Habilitar Hyper-V (Windows Pro/Enterprise)
3. Habilitar WSL2 (Windows 10/11):

```powershell
# En PowerShell como Administrador
wsl --install
wsl --set-default-version 2
```

4. Reiniciar Windows

### Problema: "Puerto 8080 ya en uso"

**Solución:** Cambiar el puerto en `application.properties`:

```properties
quarkus.http.port=8081
```

O detener el proceso que usa el puerto 8080:

```powershell
# Ver qué proceso usa el puerto 8080
netstat -ano | findstr :8080

# Detener proceso (reemplaza PID con el número obtenido)
taskkill /PID <PID> /F
```

### Problema: Permisos al ejecutar scripts

**Solución:** Ejecutar PowerShell como Administrador o cambiar política:

```powershell
# Ver política actual
Get-ExecutionPolicy

# Permitir scripts (como Administrador)
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Problema: Caracteres raros en consola

**Solución:** Configurar UTF-8 en PowerShell:

```powershell
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
chcp 65001
```

---

## 📚 Recomendaciones para Windows

1. **Usa PowerShell** en lugar de CMD (más moderno)
2. **Instala Windows Terminal** (desde Microsoft Store) - mejor experiencia
3. **Habilita WSL2** si trabajarás con Linux en el futuro
4. **Docker Desktop** es más fácil que Minikube en Windows
5. **Usa Docker Compose** si no necesitas Kubernetes obligatoriamente

---

## 📞 Ayuda Adicional

Si tienes problemas específicos de Windows:

1. Revisa los logs de Docker Desktop (icono 🐋 → Troubleshoot → View Logs)
2. Consulta al instructor
3. Revisa la documentación oficial de Docker Desktop for Windows

---

## ✅ Checklist de Validación

Marca ✅ cuando completes cada paso:

- [ ] Java 25 instalado y verificado (`java -version`)
- [ ] Docker Desktop instalado y corriendo
- [ ] Docker Compose funcional (`docker-compose --version`)
- [ ] Proyecto compilado exitosamente (`mvnw.cmd clean package`)
- [ ] Servicio corriendo en modo dev (`mvnw.cmd quarkus:dev`)
- [ ] Docker Compose iniciado (`docker-compose up -d`)
- [ ] Endpoints accesibles (http://localhost:8080/v1/products)
- [ ] Health checks funcionando (http://localhost:8080/health)

---

**Material educativo - Instituto Tecnológico de Querétaro © 2026**
