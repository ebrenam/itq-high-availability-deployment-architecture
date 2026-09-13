# Anexo: Instalar kubectl

`kubectl` es la herramienta de línea de comandos para interactuar con clusters de Kubernetes. Este documento cubre la instalación en diferentes sistemas operativos.

---

## Verificación rápida

Si ya tienes `kubectl` instalado, verifica la versión:

```bash
kubectl version --client
```

Deberías ver algo como:
```
Client Version: v1.28.0
Kustomize Version: v5.0.0
```

Si obtienes un error, procede con la instalación según tu SO.

---

## Opción 1: Linux

### Ubuntu/Debian

```bash
# Actualizar lista de paquetes
sudo apt-get update

# Instalar curl y apt-transport-https (si no están instalados)
sudo apt-get install -y curl apt-transport-https ca-certificates

# Agregar la clave GPG de Kubernetes
curl -fsSLo /etc/apt/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg

# Agregar el repositorio de Kubernetes
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list

# Actualizar nuevamente
sudo apt-get update

# Instalar kubectl
sudo apt-get install -y kubectl
```

### Fedora/RHEL/CentOS

```bash
# Crear archivo de repositorio
cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-\$basearch
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF

# Instalar kubectl
sudo yum install -y kubectl
```

### Instalación manual (todos los Linux)

Si prefieres instalar manualmente sin gestor de paquetes:

```bash
# Determinar versión más reciente
VERSION=$(curl -s https://dl.k8s.io/release/stable.txt)

# Descargar kubectl
curl -LO "https://dl.k8s.io/release/${VERSION}/bin/linux/amd64/kubectl"

# Otorgar permisos de ejecución
chmod +x kubectl

# Mover a un directorio en PATH
sudo mv kubectl /usr/local/bin/
```

### Verificación

```bash
kubectl version --client
```

---

## Opción 2: macOS

### Con Homebrew (recomendado)

```bash
# Instalar Homebrew si no lo tienes
# Ve a https://brew.sh/

# Instalar kubectl
brew install kubectl

# Verificar
kubectl version --client
```

### Instalación Manual

```bash
# Determinar arquitectura (Intel o Apple Silicon)
# Para Apple Silicon (M1/M2/M3):
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/darwin/arm64/kubectl"

# Para Intel:
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/darwin/amd64/kubectl"

# Otorgar permisos
chmod +x kubectl

# Mover a PATH
sudo mv kubectl /usr/local/bin/
```

### Verificación

```bash
kubectl version --client
```

---

## Opción 3: Windows

### Opción 3.1: Usando Chocolatey (recomendado)

Si tienes Chocolatey instalado:

```powershell
choco install kubernetes-cli
```

Luego verifica:

```powershell
kubectl version --client
```

### Opción 3.2: Descargas directas (manual)

1. **Descargar ejecutable:**
   - Ve a: https://dl.k8s.io/release/stable.txt para obtener la versión más reciente
   - Descarga desde: `https://dl.k8s.io/release/v1.28.0/bin/windows/amd64/kubectl.exe` (reemplaza `v1.28.0` con la versión actual)

2. **Guardar en un directorio en PATH:**
   - Crea carpeta: `C:\Program Files\kubectl\`
   - Mueve `kubectl.exe` a esa carpeta

3. **Agregar a PATH (si no está automático):**
   - Abre "Variables de entorno" (Environment Variables)
   - Haz clic en "Editar variables de entorno del sistema" (Edit environment variables for your account)
   - Busca la variable `Path`
   - Agrega: `C:\Program Files\kubectl\`

4. **Verificar:**
   ```powershell
   kubectl version --client
   ```

### Opción 3.3: PowerShell Script (automático)

```powershell
# Descargar y instalar automáticamente
$KubectlVersion = (curl.exe -s https://dl.k8s.io/release/stable.txt).Trim()
$KubectlUrl = "https://dl.k8s.io/release/$KubectlVersion/bin/windows/amd64/kubectl.exe"
$KubectlPath = "C:\Program Files\kubectl"

# Crear directorio si no existe
if (!(Test-Path $KubectlPath)) {
    New-Item -ItemType Directory -Path $KubectlPath -Force
}

# Descargar kubectl
Invoke-WebRequest -Uri $KubectlUrl -OutFile "$KubectlPath\kubectl.exe"

# Agregar a PATH
$env:Path += ";$KubectlPath"

# Hacer permanente
[Environment]::SetEnvironmentVariable(
    "Path",
    [Environment]::GetEnvironmentVariable("Path", "User") + ";$KubectlPath",
    "User"
)

Write-Host "kubectl instalado en $KubectlPath"
kubectl version --client
```

---

## Configuración de kubeconfig

Después de instalar `kubectl`, necesitas configurar el archivo `kubeconfig` para conectarte a tu cluster Kubernetes local.

### Si usas Minikube

```bash
# Minikube configura automáticamente kubeconfig
minikube start

# Verifica que está conectado
kubectl cluster-info
```

### Si usas Kind

```bash
# Kind configura automáticamente kubeconfig
kind create cluster

# Verifica que está conectado
kubectl cluster-info
```

### Si usas Docker Desktop con Kubernetes

1. Abre Docker Desktop
2. Ve a Preferences → Kubernetes → Enable Kubernetes
3. Espera a que se inicie
4. Verifica:
   ```bash
   kubectl cluster-info
   ```

### Localización de kubeconfig

El archivo `kubeconfig` se almacena típicamente en:

**Linux/macOS:**
```
~/.kube/config
```

**Windows (PowerShell):**
```
$env:USERPROFILE\.kube\config
```

Puedes verificar dónde está:

```bash
kubectl config view
```

---

## Pruebas de conectividad

### Prueba 1: Información del cluster

```bash
kubectl cluster-info
```

Deberías ver algo como:
```
Kubernetes control plane is running at https://127.0.0.1:8443
CoreDNS is running at https://127.0.0.1:8443/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy
```

### Prueba 2: Listar nodos

```bash
kubectl get nodes
```

Deberías ver al menos un nodo:
```
NAME       STATUS   ROLES           AGE   VERSION
minikube   Ready    control-plane   5m    v1.28.0
```

### Prueba 3: Listar pods del sistema

```bash
kubectl get pods -A
```

Deberías ver pods del sistema (`kube-system`, `kube-public`, etc.).

### Prueba 4: Acceso a API

```bash
kubectl api-resources
```

Deberías ver una lista de recursos disponibles (Deployments, Services, Pods, etc.).

---

## Troubleshooting

### Problema 1: `kubectl: command not found`

**Causa:** kubectl no está en PATH o no se instaló correctamente.

**Soluciones:**

**Linux/macOS:**
```bash
# Verifica si existe
which kubectl

# Si no existe, reinstala según tu SO
# Si existe pero no está en PATH, crea un symlink
sudo ln -s /ruta/a/kubectl /usr/local/bin/kubectl
```

**Windows:**
```powershell
# Verifica si existe
where.exe kubectl

# Si no existe, reinstala usando Chocolatey o manualmente
# Si existe pero no funciona en terminal actual, cierra y abre una nueva terminal
```

---

### Problema 2: `Unable to connect to the server: dial tcp 127.0.0.1:6443: connect: connection refused`

**Causa:** El cluster Kubernetes no está corriendo.

**Solución:**

**Si usas Minikube:**
```bash
minikube start
kubectl cluster-info
```

**Si usas Kind:**
```bash
kind create cluster
kubectl cluster-info
```

**Si usas Docker Desktop:**
- Abre Docker Desktop
- Verifica que Kubernetes está habilitado en Preferences → Kubernetes
- Espera a que se inicialice completamente

---

### Problema 3: `error: couldn't read Version from server: the server has asked for the client to provide credentials`

**Causa:** kubeconfig está corrupto o no configurado correctamente.

**Solución:**

```bash
# Elimina kubeconfig y reconfigura
rm ~/.kube/config

# Si usas Minikube
minikube start
minikube config view

# Si usas Kind
kind delete cluster
kind create cluster

# Si usas Docker Desktop
# - Reinicia Docker Desktop
# - Ve a Preferences → Kubernetes → Reset Kubernetes Cluster
```

---

### Problema 4: Permisos denegados en Linux

**Causa:** Usuario no está en grupo docker o no tiene permisos para kubeconfig.

**Solución:**

```bash
# Agregar usuario a grupo docker
sudo usermod -aG docker $USER

# Cambiar permisos de kubeconfig
chmod 600 ~/.kube/config

# Aplicar cambios (cierra sesión y reabre terminal, o ejecuta)
newgrp docker
```

---

### Problema 5: Version Mismatch (cliente vs. servidor)

**Síntoma:** Versiones de `kubectl` y Kubernetes no coinciden.

```
Client Version: v1.28.0
Server Version: v1.26.0
```

**Solución:** Descarga una versión de `kubectl` compatible:

```bash
# Descargar versión específica (ejemplo v1.26.0)
curl -LO "https://dl.k8s.io/release/v1.26.0/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/kubectl
```

Nota: Pequeñas diferencias (1.28 vs 1.26) generalmente son toleradas. Diferencias mayores pueden causar incompatibilidades.

---

## Alias útiles (opcional)

Puedes crear alias para comandos frecuentes. Agrega a `~/.bashrc`, `~/.zshrc` o `$PROFILE` en PowerShell:

```bash
# Bash/Zsh
alias k=kubectl
alias kg='kubectl get'
alias kd='kubectl describe'
alias ka='kubectl apply -f'
```

```powershell
# PowerShell
Set-Alias -Name k -Value kubectl
```

Luego puedes usar:
```bash
k get nodes
kg pods -A
kd pod <nombre>
```
