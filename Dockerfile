# ======================================
# Multi-Stage Dockerfile para Spring Boot 3.5.6
# Java 17 + Gradle
# ======================================

# --- STAGE 1: Build ---
# Usar imagen oficial de Gradle con Java 17 para compilar el proyecto
FROM gradle:8.11.1-jdk17 AS builder

# Establecer directorio de trabajo
WORKDIR /app

# Copiar archivos de configuración de Gradle primero (para aprovechar cache de Docker)
COPY build.gradle settings.gradle gradlew ./
COPY gradle ./gradle

# Copiar el código fuente
COPY src ./src

# Dar permisos de ejecución al wrapper de Gradle
RUN chmod +x gradlew

# Compilar el proyecto y generar el JAR ejecutable
# --no-daemon evita que Gradle quede en memoria consumiendo recursos
# -x test omite los tests para acelerar el build (opcional, puedes quitarlo)
RUN ./gradlew bootJar --no-daemon -x test

# --- STAGE 2: Runtime ---
# Usar imagen ligera de Java 17 solo para ejecutar la aplicación
FROM eclipse-temurin:17-jre-alpine

# Metadata de la imagen
LABEL maintainer="Juan Cruz Rivera"
LABEL description="API REST de usuarios - Spring Boot 3.5.6"
LABEL version="1.0"

# Crear usuario no-root para ejecutar la aplicación (seguridad)
RUN addgroup -S spring && adduser -S spring -G spring

# Establecer directorio de trabajo
WORKDIR /app

# Copiar el JAR compilado desde la etapa de build
COPY --from=builder /app/build/libs/usuarios-api.jar app.jar

# Cambiar propietario del archivo al usuario spring
RUN chown spring:spring app.jar

# Cambiar a usuario no-root
USER spring:spring

# Exponer el puerto 8080 (puerto por defecto de Spring Boot)
EXPOSE 8080

# Variables de entorno para optimización de JVM en contenedores
ENV JAVA_OPTS="-XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0"

# Healthcheck para verificar que la aplicación está corriendo
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8080/actuator/health || exit 1

# Comando para ejecutar la aplicación
# Se usa exec form para que Java reciba correctamente las señales del sistema (SIGTERM)
ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar app.jar"]