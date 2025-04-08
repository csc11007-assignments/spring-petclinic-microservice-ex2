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
        stage('Build and Push Main Image') {
            when {
                branch 'dev'
            }
            steps {
                script {
                    sh "mvn clean package"
                    sh "docker build -t ${DOCKERHUB_REPO}/spring-petclinic-all:main ."
                    sh "docker login -u ${DOCKERHUB_CREDENTIALS_USR} -p ${DOCKERHUB_CREDENTIALS_PSW}"
                    sh "docker push ${DOCKERHUB_REPO}/spring-petclinic-all:main"
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
