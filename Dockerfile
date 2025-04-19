FROM maven:3.9.6-eclipse-temurin-17 AS build

WORKDIR /app
COPY . .

ARG SERVICE_NAME
RUN mvn -X -pl ${SERVICE_NAME} -am clean package -DskipTests

FROM openjdk:17-jdk
WORKDIR /application

ENV SPRING_PROFILES_ACTIVE=docker
ENV JAVA_HOME=/usr/local/openjdk-17
ENV PATH=$JAVA_HOME/bin:$PATH

ARG SERVICE_PORT
EXPOSE ${SERVICE_PORT}

ARG SERVICE_NAME
COPY --from=build /app/${SERVICE_NAME}/target/*.jar app.jar

ARG SERVICE_NAME
RUN if [ "$SERVICE_NAME" = "spring-petclinic-genai-service" ]; then \
  jar xf app.jar; \
  fi

ARG SERVICE_NAME
ENTRYPOINT ["/bin/sh", "-c", "if [ \"$SERVICE_NAME\" = \"spring-petclinic-genai-service\" ]; then java -cp BOOT-INF/lib/*:BOOT-INF/classes org.springframework.samples.petclinic.genai.GenAIServiceApplication; else java -jar app.jar; fi"]
