# Evaluación

Esta evaluación está diseñada para aplicarse en la primera sesión o enviarse como un cuestionario previo. Su objetivo es medir el nivel de preparación técnica de los alumnos de 6° semestre y detectar vacíos de conocimiento antes de iniciar con la arquitectura _cloud-native_.

**Evaluación diagnóstica de entrada: Prerrequisitos de arquitectura cloud-native**

**Instrucciones:** Lee detenidamente cada reactivo y selecciona la respuesta correcta en la Sección A. Responde de forma técnica y concreta las preguntas de comando en la Sección B.

**Sección A: Conceptos teóricos y fundamentos (8 Reactivos)**

**1. En el ciclo de vida de un proyecto gestionado con Apache Maven, ¿cuál es la función principal del archivo `pom.xml`?**

- **a)** Definir las rutas de red y puertos de despliegue del servidor de aplicaciones.

- **b)** Declarar las dependencias del proyecto, la versión de Java, plugins y la configuración de construcción (_build_).

- **c)** Almacenar las credenciales y variables de entorno requeridas para conectar la base de datos.

- **d)** Compilar el código fuente directamente a lenguaje máquina ejecutable por el sistema operativo.

**2. En el diseño de APIs RESTful, ¿qué código de estado HTTP debe retornar un servidor cuando una petición `POST` procesa correctamente la creación de un nuevo recurso?**

- **a)** `200 OK`

- **b)** `201 Created`

- **c)** `204 No Content`

- **d)** `302 Found`

**3. ¿Cuál es la diferencia fundamental entre una Máquina Virtual (VM) y un Contenedor de Docker?**

- **a)** Las VMs comparten el kernel del sistema operativo anfitrión, mientras que los contenedores emulan su propio kernel completo.

- **b)** Los contenedores requieren un hipervisor de Tipo 1, mientras que las VMs se ejecutan directamente sobre el hardware.

- **c)** Los contenedores virtualizan el sistema operativo compartiendo el kernel anfitrión; las VMs virtualizan el hardware completo sobre un hipervisor.

- **d)** Los contenedores solo ejecutan código estático; las VMs son requeridas para cualquier proceso dinámico en tiempo de ejecución.

**4. ¿Qué sucede al ejecutar la instrucción `EXPOSE 8080` dentro de un `Dockerfile`?**

- **a)** Mapea automáticamente el puerto `8080` del contenedor al puerto `8080` de la máquina host.

- **b)** Abre el cortafuegos (_firewall_) del sistema operativo para permitir tráfico entrante por el puerto `8080`.

- **c)** Funciona como documentación metadata indicando en qué puerto escucha la aplicación, sin publicar el puerto por sí solo.

- **d)** Redirige todo el tráfico HTTP del puerto `80` hacia el puerto `8080`.

**5. ¿Qué comando de Linux te permite buscar una cadena de texto específica (ejemplo: `"ERROR"`) dentro de un archivo de registros (_log_) llamado `app.log`?**

- **a)** `cat app.log | find "ERROR"`

- **b)** `grep "ERROR" app.log`

- **c)** `sed -search "ERROR" app.log`

- **d)** `locate "ERROR" in app.log`

**6. Si una aplicación que corre dentro de un contenedor en Docker necesita conectarse a una base de datos local en la máquina host, ¿qué concepto asegura esta comunicación?**

- **a)** Redirección DNS vía `/etc/hosts` únicamente.

- **b)** Enrutamiento de red de Docker (_Bridge Network_) y correcto binding/mapeo de puertos e IPs.

- **c)** El archivo `pom.xml` de la aplicación Java.

- **d)** Un volumen de tipo `bind mount`.


**7. En el control de versiones con Git, ¿qué comando se utiliza para crear una nueva rama local llamada `feature/auth` y cambiarte a ella inmediatamente?**

- **a)** `git branch create feature/auth`

- **b)** `git checkout -b feature/auth`

- **c)** `git switch --create-only feature/auth`

- **d)** `git merge -b feature/auth`

**8. En un intercambio de información vía HTTP REST, ¿cuál de los siguientes fragmentos representa un payload estructurado en formato JSON válido?**

- **a)** `{ orderId: 101, status: 'PROCESSED' }`

- **b)** `{"orderId": 101, "status": "PROCESSED"}`

- **c)** `<order><id>101</id><status>PROCESSED</status></order>`

- **d)** `orderId=101&status=PROCESSED`

**Sección B: Diagnóstico práctico y CLI (2 Reactivos)**

**9. Diagnóstico de comandos Docker:**

Escribe la línea de comando exacta de Docker para ejecutar un contenedor en segundo plano (_detached_), asignándole el nombre `mi-backend`, mapeando el puerto `8080` del host con el puerto `8080` del contenedor, utilizando la imagen `ecommerce/orders:1.0`.

**10. Diagnóstico de peticiones HTTP en terminal:**

Escribe el comando `curl` exacto para enviar una petición HTTP `POST` a la URL `http://localhost:8080/v1/orders` enviando el encabezado `Content-Type: application/json` y el cuerpo JSON `{"item": "laptop", "quantity": 1}`.

**1.Hoja de respuestas - Sección A:**Reactivos 1 al 8.

1. **b)** Declarar las dependencias del proyecto, la versión de Java, plugins y la configuración de construcción (_build_).

2. **b)** `201 Created`

3. **c)** Los contenedores virtualizan el sistema operativo compartiendo el kernel anfitrión; las VMs virtualizan el hardware completo sobre un hipervisor.

4. **c)** Funciona como documentación metadata indicando en qué puerto escucha la aplicación, sin publicar el puerto por sí solo.

5. **b)** `grep "ERROR" app.log`

6. **b)** Enrutamiento de red de Docker (_Bridge Network_) y correcto binding/mapeo de puertos e IPs.

7. **b)** `git checkout -b feature/auth` (o `git switch -c feature/auth`).

8. **b)** `{"orderId": 101, "status": "PROCESSED"}` (Comillas dobles estrictas en llaves y valores de texto).

**2.Hoja de respuestas - Sección B:**Reactivos 9 y 10.

**Respuesta 9:**

```bash
docker run -d --name mi-backend -p 8080:8080 ecommerce/orders:1.0
```

**Respuesta 10:**

```bash
curl -X POST http://localhost:8080/v1/orders \
  -H "Content-Type: application/json" \
  -d '{"item": "laptop", "quantity": 1}'
```

**Matriz de nivelación sugerida (Criterio del docente)**

|**Puntaje global**|**Clasificación**|**Acción recomendada**|
|---|---|---|
|**9 - 10 aciertos**|**Avanzado**|Listo para arrancar la Unidad 1 sin ajustes.|
|**6 - 8 aciertos**|**Intermedio**|Requiere repaso rápido de CLI de Docker y sintaxis `curl` durante el laboratorio de la Unidad 1.|
|**< 6 aciertos**|**Riesgo de rezago**|Asignar la guía de instalación y el taller nivelatorio de Docker/Maven antes de la Clase 2.|