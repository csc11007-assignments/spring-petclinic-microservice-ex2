# Build and extract layers from Spring Boot executable jar
FROM eclipse-temurin:17 AS builder

WORKDIR /application

# Copy the compiled jar 
ARG ARTIFACT_NAME=spring-petclinic-api-gateway-3.4.1
COPY target/${ARTIFACT_NAME}.jar app.jar

# Extract Spring Boot layers using layertools (Spring Boot >= 2.3)
RUN java -Djarmode=layertools -jar app.jar extract

# Runtime image (smallest possible)
FROM eclipse-temurin:17-jre

WORKDIR /application
ARG EXPOSED_PORT=8080
EXPOSE ${EXPOSED_PORT}

ENV SPRING_PROFILES_ACTIVE=docker

# Copy Spring Boot layers from builder stage
COPY --from=builder /application/dependencies/ ./
COPY --from=builder /application/snapshot-dependencies/ ./
COPY --from=builder /application/spring-boot-loader/ ./
COPY --from=builder /application/application/ ./

# ENTRYPOINT
ENTRYPOINT ["java", "org.springframework.boot.loader.launch.JarLauncher"]