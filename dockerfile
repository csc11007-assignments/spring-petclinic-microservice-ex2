FROM openjdk:11
WORKDIR /app
COPY spring-petclinic-config-server/target/*.jar /app/config-server.jar
COPY spring-petclinic-discovery-server/target/*.jar /app/discovery-server.jar
COPY spring-petclinic-customers-service/target/*.jar /app/customers-service.jar
COPY spring-petclinic-visits-service/target/*.jar /app/visits-service.jar
COPY spring-petclinic-vets-service/target/*.jar /app/vets-service.jar
COPY spring-petclinic-genai-service/target/*.jar /app/genai-service.jar
COPY spring-petclinic-api-gateway/target/*.jar /app/api-gateway.jar
COPY spring-petclinic-admin-server/target/*.jar /app/admin-server.jar
COPY run-services.sh /app/
RUN chmod +x /app/run-services.sh
CMD ["/app/run-services.sh"]
