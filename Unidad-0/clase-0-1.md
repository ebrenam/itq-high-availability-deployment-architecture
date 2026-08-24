# Prerrequisitos

Definir con precisión el perfil de ingreso garantiza que los estudiantes de 6° semestre puedan enfocarse en los conceptos avanzados de la materia (_cloud-native_, orquestación, observabilidad) sin atorarse en sintaxis básica o configuraciones de entorno.

A nivel de 6° semestre de Ingeniería en Sistemas Computacionales, estos son los prerrequisitos técnicos indispensables divididos por dominio:

**1. Desarrollo e ingeniería de software (Backend)**

- **Java intermedio (JDK 17+):** Dominio de programación orientada a objetos, manejo de excepciones, colecciones (`List`, `Map`), uso de anotaciones y comprensión del ciclo de vida de un _build_ con **Apache Maven** (`pom.xml`, dependencias, _plugins_).

- **Conceptos de APIs REST:** Manejo explícito de verbos HTTP (`GET`, `POST`, `PUT`, `DELETE`), códigos de estado HTTP (`200`, `204`, `400`, `404`, `500`), parámetros de ruta/consulta y formateo de datos en **JSON**.

- **Familiaridad con frameworks backend:** Conocimiento conceptual de _Dependency Injection_ (CDI) y patrones MVC o controladores REST (equivalente a Spring Boot, Jakarta EE o Node.js/Express).

**2. Redes, sistemas operativos e infraestructura base**

- **Sistemas operativos (Linux/POSIX):** Uso fluido de la terminal/interfaz de línea de comandos (CLI). Manejo de comandos de navegación y manipulación de archivos (`cd`, `ls`, `mkdir`, `cat`, `grep`), variables de entorno (`export`, `ENV`) y permisos de archivos (`chmod`).

- **Fundamentos de redes:** Comprensión de conceptos como IP, subredes, puertos de red (`80`, `443`, `8080`), DNS, resolución de nombres y modelo cliente-servidor.

- **Manejo de herramientas HTTP en terminal:** Uso básico de `curl` para enviar peticiones HTTP y formateo con `jq`.

**3. Contenedores y virtualización (Docker básico)**

- **Fundamentos de Docker:** Diferencia conceptual entre una imagen y un contenedor, máquina virtual vs. contenedor.

- **Comandos esenciales de Docker:** Uso funcional de la CLI para construir y ejecutar contenedores (`docker build`, `docker run`, `docker ps`, `docker logs`, `docker exec`).

- **Conceptos de almacenamiento y red en contenedores:** Noción básica de mapeo de puertos (`-p 8080:8080`) y montaje de volúmenes persistentes (`-v`).

**4. Herramientas de control de versiones y entorno de desarrollo**

- **Git:** Clonado de repositorios (`git clone`), navegación por ramas (`git checkout`), gestión de versiones (`git pull`, `git status`) y etiquetado (`git tag`).

- **Entorno de desarrollo (IDE):** VS Code, IntelliJ IDEA o Eclipse configurado con JDK 17+ y plugins para Java/Docker.

**Evaluación diagnóstica rápida (Checklist de entrada)**

Se recomienda enviar el siguiente cuestionario/autoevaluación de 5 preguntas a los alumnos antes de la Clase 1:

1. ¿Puedes compilar y ejecutar una aplicación Java con Maven desde la terminal usando `mvn clean package`?

2. ¿Sabes cómo construir una imagen con un `Dockerfile` simple y poner a correr el contenedor mapeando un puerto local?

3. ¿Comprendes la diferencia entre enviar un payload JSON mediante una petición `POST` y recibirlo en una petición `GET`?

4. ¿Has utilizado comandos de Git para cambiarte de rama o revisar el estado del código?

5. ¿Sabes cómo consultar los logs de un proceso o contenedor que está corriendo en segundo plano desde la CLI?