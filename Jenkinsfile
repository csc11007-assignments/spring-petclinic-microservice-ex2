pipeline {
    agent any
    environment {
        DOCKERHUB_REPO = 'csc11007'
        COMMIT_ID = "${env.GIT_COMMIT.take(7)}"
    }
    stages {
        stage('Checkout') {
            steps {
                git branch: "${BRANCH_NAME}",
                    url: 'https://github.com/csc11007-assignments/spring-petclinic-microservice-ex2.git'
            }
        }
        stage('Detect Changed Service') {
            when {
                not { branch 'main' }
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

                    def previousCommit = sh(script: 'git rev-parse HEAD^ || git rev-list --max-parents=0 HEAD', returnStdout: true).trim()

                    def changedService = null
                    services.each { service ->
                        def changes = sh(script: "git diff --name-only ${previousCommit} HEAD -- spring-petclinic-${service}", returnStdout: true).trim()
                        if (changes) {
                            changedService = service
                            echo "Detected changes in service: ${service}"
                        }
                    }

                    if (!changedService) {
                        error "No changes detected in any service folder. Aborting build."
                    }

                    env.CHANGED_SERVICE = changedService
                }
            }
        }
        stage('Build and Push Feature Image') {
            when {
                not { branch 'main' }
            }
            steps {
                script {
                    def serviceName = env.CHANGED_SERVICE
                    def imageTag = "${COMMIT_ID}"
                    withCredentials([usernamePassword(
                        credentialsId: 'dockerhub-credentials-id',
                        usernameVariable: 'DOCKER_USER',
                        passwordVariable: 'DOCKER_PASS'
                    )]) {
                        sh 'docker login -u $DOCKER_USER -p $DOCKER_PASS'
                        def imageTagFull = "${DOCKERHUB_REPO}/spring-petclinic-${serviceName}:${imageTag}"
                        sh 'mvn clean package -pl spring-petclinic-' + serviceName + ' -am -q'
                        sh 'docker build -t ' + imageTagFull + ' ./spring-petclinic-' + serviceName
                        sh 'docker push ' + imageTagFull
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
