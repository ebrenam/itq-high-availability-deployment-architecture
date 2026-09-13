# Anexo: Instalar Kubernetes Local

Este documento te guía para instalar un clúster Kubernetes local en tu máquina. Elige la opción que mejor se adapte a tu sistema operativo.

---

## Opción 1: Minikube (Recomendado para Linux/macOS)

Minikube es la opción más simple para crear un clúster Kubernetes de un solo nodo localmente.

### Instalación en Linux

```bash
# Descarga el binario de Minikube
curl -LO https://github.com/kubernetes/minikube/releases/latest/download/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube

# Inicia Minikube (usa VirtualBox, KVM, Docker o Podman como driver)
minikube start --driver=docker
# O si prefieres otro driver:
# minikube start --driver=virtualbox
# minikube start --driver=kvm2
```

### Instalación en macOS

```bash
# Usa Homebrew (recomendado)
brew install minikube

# O descarga el binario manualmente
curl -LO https://github.com/kubernetes/minikube/releases/latest/download/minikube-darwin-arm64  # Para Apple Silicon
curl -LO https://github.com/kubernetes/minikube/releases/latest/download/minikube-darwin-amd64  # Para Intel

# Otorga permisos ejecutables
chmod +x minikube-darwin-*
sudo mv minikube-darwin-* /usr/local/bin/minikube

# Inicia Minikube
minikube start --driver=docker
```

### Verificación

```bash
minikube version
kubectl cluster-info
minikube status
```

### Acceso al Dashboard (opcional)

```bash
minikube dashboard
```

---

## Opción 2: Kind (Recomendado para Windows + WSL)

Kind (Kubernetes in Docker) es ligero y funciona bien en Windows con WSL.

### Instalación en Windows + WSL

```bash
# Dentro de WSL, descarga el binario de Kind
wget https://github.com/kubernetes-sigs/kind/releases/latest/download/kind-linux-amd64
chmod +x kind-linux-amd64
sudo mv kind-linux-amd64 /usr/local/bin/kind

# Crea un clúster Kind
kind create cluster --name local-cluster
```

### Instalación en Linux/macOS

```bash
# Usa Homebrew (para macOS y algunos sistemas Linux)
brew install kind

# O descarga manualmente
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind

# Crea un clúster
kind create cluster --name local-cluster
```

### Verificación

```bash
kind version
kubectl cluster-info --context kind-local-cluster
```

### Eliminar el Clúster

```bash
kind delete cluster --name local-cluster
```

---

## Opción 3: Docker Desktop (Simple pero menos educativo)

Si ya tienes Docker Desktop instalado, puedes habilitar Kubernetes integrado.

### En macOS

1. Abre **Docker Desktop** → **Preferences**
2. Ve a **Kubernetes**
3. Marca la opción **"Enable Kubernetes"**
4. Click en **"Apply & Restart"**
5. Espera a que inicie (puede tomar 2-3 minutos)

### En Windows

1. Abre **Docker Desktop** → **Settings**
2. Ve a **Kubernetes**
3. Marca **"Enable Kubernetes"**
4. Click en **"Apply & Restart"**

### Verificación

```bash
kubectl cluster-info
kubectl get nodes
```

---

## Verificación General (Todas las Opciones)

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

## Tamaño de Almacenamiento

- **Minikube:** ~5-10 GB (varía según driver)
- **Kind:** ~2-3 GB
- **Docker Desktop + Kubernetes:** Compartido con Docker (típicamente 50-100 GB total)
