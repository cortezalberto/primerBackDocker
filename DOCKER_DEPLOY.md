# Guía de Despliegue con Docker y Render

Esta guía explica cómo construir, probar y desplegar la aplicación usando Docker y Render.

## Requisitos Previos

- **Docker Desktop** instalado y ejecutándose (descarga desde https://www.docker.com/products/docker-desktop/)
- Cuenta en **Render** (gratis en https://render.com/)
- **Git** instalado para subir el código a GitHub/GitLab

## 1. Probar Docker Localmente

### 1.1 Iniciar Docker Desktop

Asegúrate de que Docker Desktop esté ejecutándose antes de continuar.

### 1.2 Construir la Imagen Docker

```bash
# Construir la imagen (esto puede tomar 5-10 minutos la primera vez)
docker build -t usuarios-api:latest .

# Verificar que la imagen se creó correctamente
docker images | grep usuarios-api
```

**Explicación del proceso:**
- **Stage 1 (Builder):** Usa Gradle 8.11.1 con Java 17 para compilar el código y generar el JAR
- **Stage 2 (Runtime):** Copia solo el JAR al contenedor final usando Java 17 JRE (imagen más liviana)

### 1.3 Ejecutar el Contenedor

```bash
# Ejecutar el contenedor en modo producción
docker run -d \
  --name usuarios-api \
  -p 8080:8080 \
  usuarios-api:latest

# Ver logs en tiempo real
docker logs -f usuarios-api

# Verificar que el contenedor está corriendo
docker ps
```

### 1.4 Probar la API

Una vez que veas en los logs "Started UsuariosEnMemoriaApplication", prueba:

```bash
# Healthcheck
curl http://localhost:8080/actuator/health

# Crear un usuario
curl -X POST http://localhost:8080/api/usuarios \
  -H "Content-Type: application/json" \
  -d '{"nombre":"Juan Pérez","email":"juan@example.com","password":"123456"}'

# Listar usuarios
curl http://localhost:8080/api/usuarios

# Swagger UI
# Abre en el navegador: http://localhost:8080/swagger-ui.html
```

### 1.5 Ejecutar con Variables de Entorno (Modo Dev)

```bash
# Detener y eliminar el contenedor anterior
docker stop usuarios-api
docker rm usuarios-api

# Ejecutar con perfil de desarrollo (SQL logs habilitados)
docker run -d \
  --name usuarios-api \
  -p 8080:8080 \
  -e SPRING_PROFILES_ACTIVE=dev \
  -e JPA_SHOW_SQL=true \
  usuarios-api:latest

# Ver logs con queries SQL
docker logs -f usuarios-api
```

### 1.6 Comandos Útiles

```bash
# Ver logs del contenedor
docker logs usuarios-api

# Entrar al contenedor (para debugging)
docker exec -it usuarios-api sh

# Detener el contenedor
docker stop usuarios-api

# Eliminar el contenedor
docker rm usuarios-api

# Eliminar la imagen
docker rmi usuarios-api:latest

# Ver estadísticas de recursos (CPU, memoria)
docker stats usuarios-api
```

## 2. Desplegar en Render

Render detectará automáticamente el `Dockerfile` y `render.yaml` para construir y desplegar tu aplicación.

### 2.1 Preparar el Repositorio Git

```bash
# Asegúrate de estar en la raíz del proyecto
cd C:\2025Desarrollo\Juan Cruz\usuarios-en-memoria-api-documentada-main\usuarios-en-memoria-api-documentada-main

# Verificar el estado de Git
git status

# Agregar los nuevos archivos
git add Dockerfile .dockerignore render.yaml build.gradle src/main/resources/application.properties DOCKER_DEPLOY.md

# Hacer commit
git commit -m "Add Docker support and Render configuration"

# Subir a tu repositorio remoto
git push origin main
```

### 2.2 Configurar Render desde el Dashboard

#### Opción A: Deploy Manual (Recomendado para primera vez)

1. Ve a https://dashboard.render.com/
2. Haz clic en **"New +"** → **"Web Service"**
3. Conecta tu repositorio de GitHub/GitLab
4. Render detectará automáticamente el `Dockerfile`
5. Configura:
   - **Name:** `usuarios-api` (o el nombre que prefieras)
   - **Region:** `Oregon` (o el más cercano)
   - **Branch:** `main`
   - **Runtime:** `Docker` (detectado automáticamente)
   - **Plan:** `Free` (o el que prefieras)

6. **Variables de Entorno** (opcional):
   ```
   SPRING_PROFILES_ACTIVE=prod
   JPA_SHOW_SQL=false
   H2_CONSOLE_ENABLED=false
   JAVA_OPTS=-XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0
   ```

7. Haz clic en **"Create Web Service"**

#### Opción B: Deploy con Blueprint (render.yaml)

Si prefieres usar el archivo `render.yaml` para configuración como código:

1. Ve a https://dashboard.render.com/
2. Haz clic en **"New +"** → **"Blueprint"**
3. Conecta tu repositorio
4. Render leerá automáticamente el `render.yaml`
5. Revisa la configuración y haz clic en **"Apply"**

### 2.3 Monitorear el Deploy

1. En el dashboard de Render, verás el proceso de build en tiempo real
2. El primer deploy puede tomar **10-15 minutos** (Render construye la imagen desde cero)
3. Una vez completado, verás el estado **"Live"** en verde
4. Render te asignará una URL pública: `https://usuarios-api-XXXX.onrender.com`

### 2.4 Probar la API en Producción

```bash
# Reemplaza la URL con la que te asignó Render
RENDER_URL="https://usuarios-api-XXXX.onrender.com"

# Healthcheck
curl $RENDER_URL/actuator/health

# Crear usuario
curl -X POST $RENDER_URL/api/usuarios \
  -H "Content-Type: application/json" \
  -d '{"nombre":"Juan Pérez","email":"juan@example.com","password":"123456"}'

# Listar usuarios
curl $RENDER_URL/api/usuarios

# Swagger UI
# Abre: https://usuarios-api-XXXX.onrender.com/swagger-ui.html
```

### 2.5 Importantes sobre el Plan Free de Render

El plan gratuito tiene limitaciones:

- **750 horas/mes** de uso
- **512 MB RAM** por servicio
- **El servicio se apaga después de 15 minutos de inactividad** (cold start)
- **Primera request después de inactividad puede tomar 30-60 segundos** (Render tiene que despertar el contenedor)
- Sin dominios personalizados (solo subdominios de Render)

**Recomendación:** Para producción real, considera el plan Starter ($7/mes) que incluye:
- Siempre activo (sin cold starts)
- 512 MB RAM
- Dominios personalizados

## 3. Monitoreo y Logs

### 3.1 Ver Logs en Render

1. Ve al dashboard de tu servicio en Render
2. Haz clic en **"Logs"** en el menú izquierdo
3. Verás logs en tiempo real de tu aplicación

### 3.2 Endpoints de Actuator

Tu aplicación expone los siguientes endpoints de monitoreo:

```bash
# Healthcheck (usado por Render para verificar que la app está viva)
GET /actuator/health

# Información de la aplicación
GET /actuator/info
```

## 4. Actualizar la Aplicación en Render

Cada vez que hagas `git push` a tu branch principal, Render:

1. Detectará automáticamente el cambio
2. Construirá una nueva imagen Docker
3. Desplegará la nueva versión
4. Realizará un **zero-downtime deployment** (sin tiempo de inactividad)

```bash
# Después de hacer cambios en el código:
git add .
git commit -m "Update feature X"
git push origin main

# Render automáticamente iniciará un nuevo deploy
```

## 5. Solución de Problemas

### Error: Docker no está ejecutándose

```
error during connect: Head "http://%2F%2F.%2Fpipe%2FdockerDesktopLinuxEngine/_ping"
```

**Solución:** Inicia Docker Desktop desde el menú de Windows.

### Error: Build falla en Render

1. Revisa los logs del build en el dashboard de Render
2. Verifica que el `Dockerfile` esté en la raíz del proyecto
3. Asegúrate de que `gradlew` tenga permisos de ejecución (Git debe preservarlos)

### Error: Aplicación no responde (503)

- **En plan Free:** Espera 30-60 segundos (cold start)
- Revisa los logs en Render para ver errores de inicio

### Error: Puerto incorrecto

Render asigna automáticamente el puerto 8080 (puerto por defecto de Spring Boot). No necesitas configurar nada adicional.

## 6. Optimizaciones Adicionales

### 6.1 Reducir Tiempo de Build

El Dockerfile usa **multi-stage build** para optimizar:
- Cachea dependencias de Gradle en layers separados
- Solo copia el código fuente cuando cambia
- La imagen final solo contiene el JRE (no el JDK completo)

### 6.2 Monitoreo con Logs

Para debugging en producción, puedes habilitar logs SQL temporalmente:

```bash
# En Render Dashboard → Environment → Add Environment Variable:
JPA_SHOW_SQL=true
```

Luego haz clic en **"Redeploy"** para aplicar cambios.

### 6.3 CORS para Frontend

Si tu frontend está en un dominio diferente, actualiza `WebConfig.java`:

```java
@Override
public void addCorsMappings(CorsRegistry registry) {
    registry.addMapping("/api/**")
            .allowedOrigins(
                "http://localhost:3000",
                "https://tu-frontend.vercel.app"  // Agregar dominio de producción
            )
            // ...
}
```

## 7. Recursos Adicionales

- **Documentación de Render:** https://docs.render.com/
- **Dockerfile Best Practices:** https://docs.docker.com/develop/develop-images/dockerfile_best-practices/
- **Spring Boot con Docker:** https://spring.io/guides/topicals/spring-boot-docker/
- **Multi-stage builds:** https://docs.docker.com/build/building/multi-stage/

---

**¡Felicitaciones!** Tu API REST ahora está dockerizada y lista para producción en Render.