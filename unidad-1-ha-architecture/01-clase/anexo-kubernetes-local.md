# Anexo: Instalar Kubernetes Local

Este documento te guía para instalar un clúster Kubernetes local en tu máquina. Elige la opción que mejor se adapte a tu sistema operativo y preferencias.

---

## 📊 Matriz Comparativa por Sistema Operativo

Antes de elegir, consulta esta tabla para ver qué funciona mejor en tu SO:

| **SO** | **Minikube** | **Kind** | **Docker Desktop** |
|--------|---|---|---|
| **Linux** | ✅ Recomendado (más rápido) | ✅ Alternativa (más ligero) | ❌ No disponible |
| **macOS** | ✅ Muy recomendado (fácil con Homebrew) | ✅ Alternativa | ✅ Alternativa |
| **Windows 11+ Pro/Enterprise (Hyper-V)** | ⚠️ Factible (requiere Hyper-V) | ✅ Recomendado (WSL) | ✅ Recomendado |
| **Windows 11 Home (sin Hyper-V)** | ⚠️ Factible (requiere VirtualBox) | ✅ Recomendado (WSL) | ⚠️ Requiere upgrade |

**Recomendación rápida:**
- ![linux](images/linux.png) **Linux:** Minikube
- 🍎 **macOS:** Minikube (o Docker Desktop si ya lo usas)
- ![win](images/windows.png) **Windows:** Kind + WSL2 (más simple que Minikube)

---

## Instalación por Sistema Operativo

### ![linux](images/linux.png) Linux

#### Opción A: Minikube (Recomendada)

```bash
# Descarga el binario
curl -LO https://github.com/kubernetes/minikube/releases/latest/download/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube

# Inicia con Docker (más rápido)
minikube start --driver=docker

# O con otro driver si prefieres:
# minikube start --driver=virtualbox
# minikube start --driver=kvm2
# minikube start --driver=podman
```

**Verificación:**
```bash
minikube version
minikube status
kubectl cluster-info
minikube dashboard  # Ver dashboard (opcional)
```

**Dashboard (opcional):**
El dashboard de Minikube es una interfaz web gráfica para ver tu clúster. Úsalo para visualizar:
- Pods, Deployments, Services corriendo
- Consumo de recursos
- Logs de contenedores

```bash
# Abre automáticamente el dashboard en tu navegador
minikube dashboard

# Si no se abre automáticamente, copia la URL que se imprime en terminal
# y abrela manualmente en tu navegador
```

#### Opción B: Kind (Alternativa ligera)

```bash
# Descarga Kind
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind

# Crea un clúster
kind create cluster --name local-cluster
```

**Verificación:**
```bash
kind version
kubectl cluster-info --context kind-local-cluster
```

---

### 🍎 macOS

#### Opción A: Minikube (Recomendada)

```bash
# Usa Homebrew (más fácil)
brew install minikube

# O descarga manualmente
# Para Apple Silicon (M1/M2/M3):
curl -LO https://github.com/kubernetes/minikube/releases/latest/download/minikube-darwin-arm64
# Para Intel:
curl -LO https://github.com/kubernetes/minikube/releases/latest/download/minikube-darwin-amd64

# Si descargaste manualmente:
chmod +x minikube-darwin-*
sudo mv minikube-darwin-* /usr/local/bin/minikube

# Inicia Minikube
minikube start --driver=docker
```

**Verificación:**
```bash
minikube version
minikube status
kubectl cluster-info
```

**Dashboard (opcional):**
El dashboard de Minikube es una interfaz web gráfica para ver tu clúster. Úsalo para visualizar:
- Pods, Deployments, Services corriendo
- Consumo de recursos
- Logs de contenedores

```bash
# Abre automáticamente el dashboard en tu navegador
minikube dashboard

# Si no se abre automáticamente, copia la URL que se imprime en terminal
# y abrela manualmente en tu navegador
```

#### Opción B: Kind

```bash
# Usa Homebrew
brew install kind

# O descarga manualmente
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-darwin-arm64  # Apple Silicon
# O
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-darwin-amd64   # Intel

chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind

# Crea un clúster
kind create cluster --name local-cluster
```

#### Opción C: Docker Desktop (si ya lo tienes)

1. Abre **Docker Desktop** → **Preferences**
2. Ve a **Kubernetes**
3. Marca **"Enable Kubernetes"**
4. Click en **"Apply & Restart"**
5. Espera 2-3 minutos

**Verificación:**
```bash
kubectl cluster-info
```

---

### ![win](images/windows.png) Windows

#### Opción A: Kind + WSL2 (Recomendada)

**Prerrequisito:** Tener WSL2 instalado.

```powershell
# En PowerShell como Administrador

# Descarga Kind
curl -Lo kind.exe https://kind.sigs.k8s.io/dl/v0.20.0/kind-windows-amd64
# Mueve a un directorio en PATH, por ejemplo:
Move-Item .\kind.exe 'C:\Program Files\kind.exe'

# Verifica
kind version

# Crea un clúster
kind create cluster --name local-cluster
```

Luego en **WSL2 terminal:**
```bash
# Dentro de WSL2, kubectl ya debería funcionar
kubectl cluster-info --context kind-local-cluster
```

#### Opción B: Minikube con Hyper-V (Windows 11 Pro/Enterprise)

```powershell
# En PowerShell como Administrador

# Habilita Hyper-V (si no está ya habilitado)
Enable-WindowsOptionalFeature -FeatureName Microsoft-Hyper-V-All -Online

# Descarga Minikube
curl -Lo minikube.exe https://github.com/kubernetes/minikube/releases/latest/download/minikube-windows-amd64
Move-Item .\minikube.exe 'C:\Program Files\minikube.exe'

# Inicia con Hyper-V
minikube start --driver=hyperv

# Verifica
minikube status
kubectl cluster-info
```

#### Opción C: Minikube con VirtualBox (Cualquier Windows)

```powershell
# En PowerShell como Administrador

# Descarga VirtualBox desde https://www.virtualbox.org/
# (Instala manualmente)

# Descarga Minikube
curl -Lo minikube.exe https://github.com/kubernetes/minikube/releases/latest/download/minikube-windows-amd64
Move-Item .\minikube.exe 'C:\Program Files\minikube.exe'

# Inicia con VirtualBox
minikube start --driver=virtualbox

# Verifica
minikube status
kubectl cluster-info
```

#### Opción D: Docker Desktop (si ya lo tienes)

1. Abre **Docker Desktop** → **Settings**
2. Ve a **Kubernetes**
3. Marca **"Enable Kubernetes"**
4. Click en **"Apply & Restart"**

**Verificación:**
```bash
kubectl cluster-info
```

---

## Verificación General (todas las opciones)

Después de instalar cualquier opción, verifica que todo funciona:

```bash
# Ver información del clúster
kubectl cluster-info

# Ver nodos disponibles
kubectl get nodes

# Ver pods del sistema
kubectl get pods -n kube-system

# Ver componentes del control plane
kubectl get componentstatuses  # (Deprecated en versiones nuevas, puede no funcionar)
```

---

## Troubleshooting

### Problema: `kubectl: command not found`

**Solución:** Necesitas instalar `kubectl` por separado:

```bash
# macOS
brew install kubectl

# Linux
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

# Windows (en Powershell)
choco install kubernetes-cli  # Si tienes Chocolatey
```

### Problema: Minikube no inicia

**Causa común:** El driver no está disponible o no está instalado.

**Soluciones:**
- Si elegiste `--driver=docker`, asegúrate que Docker Desktop esté corriendo
- Si elegiste `--driver=virtualbox`, asegúrate que VirtualBox esté instalado
- Intenta con otro driver: `minikube start --driver=docker`

### Problema: Permisos denegados al ejecutar Minikube/Kind

```bash
# En Linux, agrega tu usuario al grupo docker
sudo usermod -aG docker $USER
# Luego cierra sesión y vuelve a iniciar
```

### Problema: Clúster Kind se queda en "creating"

```bash
# Reinicia Docker
sudo systemctl restart docker  # Linux
# O reinicia Docker Desktop    # macOS/Windows

# Luego vuelve a intentar
kind create cluster --name local-cluster
```

---

## Tamaño de almacenamiento

- **Minikube:** ~5-10 GB (varía según driver)
- **Kind:** ~2-3 GB
- **Docker Desktop + Kubernetes:** Compartido con Docker (típicamente 50-100 GB total)
