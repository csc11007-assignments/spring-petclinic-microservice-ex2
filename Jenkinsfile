pipeline {
    agent any
    environment {
        DOCKERHUB_REPO = 'csc11007'
    }
    stages {
        stage('Checkout') {
            steps {
                git branch: "${BRANCH_NAME}", 
                    url: 'https://github.com/csc11007-assignments/spring-petclinic-microservice-ex2.git'
            }
        }
        stage('Build and Push Images') {
            when {
                branch 'main'
            }
            steps {
                script {
                    def services = [
                        'config-server',
                        'discovery-server',
                        'customers-service',
                        'visits-service',
                        'vets-service',
                        'genai-service',
                        'api-gateway',
                        'admin-server'
                    ]
                    withCredentials([usernamePassword(
                        credentialsId: 'dockerhub-credentials-id',
                        usernameVariable: 'DOCKER_USER',
                        passwordVariable: 'DOCKER_PASS'
                    )]) {
                        sh 'docker login -u $DOCKER_USER -p $DOCKER_PASS'
                        services.each { service ->
                            def imageTag = "${DOCKERHUB_REPO}/spring-petclinic-${service}:main"
                            sh 'mvn clean package -pl spring-petclinic-' + service + ' -am -q'
                            sh 'docker build -f Dockerfile.common -t ' + imageTag + ' ./spring-petclinic-' + service
                            sh 'docker push ' + imageTag
                        }
                    }
                }
            }
        }
    }
    post {
        always {
            sh 'docker system prune -f'
        }
    }
}
