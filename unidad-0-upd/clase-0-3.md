# Guía comprimida

Esta guía comprimida está diseñada para regularizar a los estudiantes que obtuvieron un puntaje menor a 6 en la evaluación diagnóstica. Provee las herramientas esenciales de desarrollo para ponerse al día antes del primer laboratorio.

**Guía de nivelación rápida: Terminal, Maven y Docker**

**Objetivo:** Proporcionar los comandos y conceptos mínimos indispensables para construir, empaquetar y ejecutar aplicaciones _cloud-native_ sin depender de interfaces gráficas.

### 1. Comandos esenciales de terminal (CLI)

En arquitecturas distribuidas y contenedores, el trabajo diario ocurre dentro de una terminal Linux/POSIX.

```bash
# Navegación y estructura de archivos
pwd                             # Muestra la ruta actual de trabajo
ls -la                          # Lista todos los archivos (incluyendo ocultos) con detalles
cd proyecto/                    # Entra al directorio 'proyecto'
cd ..                           # Sube un nivel de directorio

# Filtrado y monitoreo de logs
cat application.log             # Muestra todo el contenido del archivo
grep -i "ERROR" application.log # Busca líneas que contengan "ERROR" (ignora mayúsculas/minúsculas)
tail -f -n 100 application.log  # Muestra las últimas 100 líneas y sigue los cambios en tiempo real

# Pruebas de red y peticiones HTTP
curl -i http://localhost:8080/v1/orders # Petición GET inspeccionando encabezados (headers)

curl -X POST http://localhost:8080/v1/orders \
  -H "Content-Type: application/json" \
  -d '{"item": "laptop", "quantity": 1}'  # Petición POST enviando un cuerpo en JSON
```

### 2. Gestión del ciclo de vida con Apache Maven

Maven administra las dependencias y la compilación del proyecto Java mediante el archivo `pom.xml`.

```bash
# Limpia artefactos previos y compila el código fuente
mvn clean compile

# Compila, ejecuta pruebas unitarias y empaqueta el código en un archivo .jar
mvn clean package

# Empaqueta omitiendo la ejecución de pruebas unitarias (util para builds rápidos)
mvn clean package -DskipTests

# Ejecuta la aplicación Quarkus en modo desarrollo (recarga en caliente / live-reload)
mvn quarkus:dev
```

- **Estructura estándar de proyecto:**
    
    - `pom.xml`: Declaración de dependencias, plugins y versión del JDK.
        
    - `src/main/java/`: Código fuente Java.
        
    - `src/main/resources/`: Archivos de configuración (`application.properties`).
        

### 3. Operaciones fundamentales con Docker

Un contenedor es un proceso aislado que virtualiza el sistema operativo a nivel de kernel, compartiendo los recursos del anfitrión (_host_).

```bash
# Construcción de imágenes
docker build -t ecommerce/orders:1.0 .   # Construye la imagen usando el Dockerfile del directorio actual

# Ejecución y administración de contenedores
docker run -d -p 8080:8080 --name backend ecommerce/orders:1.0
# Banderas clave:
#  -d : Ejecuta en segundo plano (detached)
#  -p : Mapea [Puerto Host]:[Puerto Contenedor]
#  --name : Asigna un nombre ejecutable al contenedor

docker ps                                # Lista los contenedores en ejecución
docker ps -a                             # Lista todos los contenedores (incluyendo detenidos)

# Inspección y diagnóstico
docker logs -f backend                   # Visualiza los logs en tiempo real del contenedor 'backend'
docker exec -it backend /bin/bash        # Abre una terminal interactiva dentro del contenedor

# Limpieza de entorno
docker stop backend                      # Detiene el contenedor de forma segura
docker rm backend                        # Elimina el contenedor detenido
docker rmi ecommerce/orders:1.0          # Elimina la imagen del almacenamiento local
```

### Cheatsheet de conceptos clave

| **Concepto**            | **Definición rápida**                                                                                               |
| ----------------------- | ------------------------------------------------------------------------------------------------------------------- |
| **JSON**                | Formato de texto para intercambio de datos. Exige comillas dobles en llaves y valores de texto: `{"key": "value"}`. |
| **Dockerfile**          | Receta con instrucciones (`FROM`, `COPY`, `RUN`, `CMD`) para empaquetar una aplicación y su entorno.                |
| **Port Binding (`-p`)** | Enlace que redirige el tráfico que llega a la máquina física hacia la interfaz de red interna del contenedor.       |