# Dockerfile para catalog-service - Unidad 1
# Este Dockerfile crea una imagen optimizada en dos etapas:
# Etapa 1: Compilación del proyecto con Maven
# Etapa 2: Imagen runtime ligera solo con el JAR ejecutable

# ===========================
# STAGE 1: Build
# ===========================
FROM maven:3.9.6-eclipse-temurin-25 AS build

LABEL stage=builder
LABEL maintainer="ITQ - Arquitectura de Despliegue de Alta Disponibilidad"

# Establecer directorio de trabajo
WORKDIR /usr/src/app

# Copiar solo el POM primero para aprovechar el caché de Docker en las dependencias
COPY pom.xml .

# Descargar dependencias de Maven (esta capa se cachea si pom.xml no cambia)
RUN mvn dependency:go-offline -B

# Copiar el código fuente
COPY src ./src

# Compilar el proyecto (genera el quarkus-app en target/)
RUN mvn package -DskipTests -B

# ===========================
# STAGE 2: Runtime
# ===========================
FROM eclipse-temurin:25-jre-jammy

LABEL maintainer="ITQ - Arquitectura de Despliegue de Alta Disponibilidad"
LABEL service="catalog-service"
LABEL version="1.0.0"
LABEL unit="Unidad-1"

# Configuración de idioma
ENV LANGUAGE='en_US:en'

# Directorio de trabajo para la aplicación
WORKDIR /deployments/

# Copiar los artefactos compilados desde la etapa de build
# Quarkus genera una estructura fast-jar en target/quarkus-app/
COPY --from=build /usr/src/app/target/quarkus-app/lib/ /deployments/lib/
COPY --from=build /usr/src/app/target/quarkus-app/*.jar /deployments/
COPY --from=build /usr/src/app/target/quarkus-app/app/ /deployments/app/
COPY --from=build /usr/src/app/target/quarkus-app/quarkus/ /deployments/quarkus/

# Exponer el puerto de la aplicación
EXPOSE 8080

# Usuario no-root para seguridad (UID 185 es el estándar de Quarkus)
USER 185

# Variables de entorno para la JVM
ENV JAVA_OPTS="-Dquarkus.http.host=0.0.0.0 -Djava.util.logging.manager=org.jboss.logmanager.LogManager"
ENV JAVA_APP_JAR="/deployments/quarkus-run.jar"

# Comando de ejecución
ENTRYPOINT [ "sh", "-c", "java $JAVA_OPTS -jar $JAVA_APP_JAR" ]
