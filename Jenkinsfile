pipeline {
    agent any
    environment {
        DOCKERHUB_CREDENTIALS = credentials('dockerhub-credentials-id')
        DOCKERHUB_REPO = 'csc11007'
    }
    stages {
        stage('Checkout') {
            steps {
                git branch: '${BRANCH_NAME}', 
                    url: 'https://github.com/spring-petclinic/spring-petclinic-microservices.git'
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
                    services.each { service ->
                        sh "mvn clean package -pl spring-petclinic-${service} -am"
                        sh "docker build -t ${DOCKERHUB_REPO}/spring-petclinic-${service}:main ./spring-petclinic-${service}"
                        sh "docker login -u ${DOCKERHUB_CREDENTIALS_USR} -p ${DOCKERHUB_CREDENTIALS_PSW}"
                        sh "docker push ${DOCKERHUB_REPO}/spring-petclinic-${service}:main"
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
