#!/bin/bash
java -jar /app/config-server.jar --server.port=8888 &
java -jar /app/discovery-server.jar --server.port=8761 &
java -jar /app/customers-service.jar --server.port=8081 &
java -jar /app/visits-service.jar --server.port=8082 &
java -jar /app/vets-service.jar --server.port=8083 &
java -jar /app/genai-service.jar --server.port=8084 &
java -jar /app/api-gateway.jar --server.port=8080 &
java -jar /app/admin-server.jar --server.port=9090 &
wait
