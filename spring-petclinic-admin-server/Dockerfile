# spring-petclinic-admin-server/Dockerfile
# ================================
# 🌱 Stage 1: Build and extract layers from Spring Boot executable jar
# ================================
FROM eclipse-temurin:17 AS builder

WORKDIR /application

# Copy the compiled jar 
ARG ARTIFACT_NAME=spring-petclinic-admin-server-3.4.1
COPY target/${ARTIFACT_NAME}.jar app.jar

RUN java -Djarmode=layertools -jar app.jar extract

# Runtime image with minimal footprint
FROM eclipse-temurin:17-jre

WORKDIR /application

# Explicitly set the admin server port to match configuration
ARG EXPOSED_PORT=9090
EXPOSE ${EXPOSED_PORT}

ENV SPRING_PROFILES_ACTIVE=docker

COPY --from=builder /application/dependencies/ ./
RUN true  # Creates a new layer to improve caching
COPY --from=builder /application/spring-boot-loader/ ./
RUN true  # Creates a new layer to improve caching
COPY --from=builder /application/snapshot-dependencies/ ./
RUN true  # Creates a new layer to improve caching
COPY --from=builder /application/application/ ./

# Use the Spring Boot JarLauncher directly rather than a shell script
ENTRYPOINT ["java", "org.springframework.boot.loader.launch.JarLauncher"]