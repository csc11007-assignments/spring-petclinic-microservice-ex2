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
        stage('Detect Changed Services') {
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

                    def mainCommit = sh(script: 'git fetch origin main && git rev-parse origin/main', returnStdout: true).trim()

                    def changedFiles = []
                    try {
                        changedFiles = sh(script: "git diff --name-only ${mainCommit} HEAD", returnStdout: true).trim().split("\n")
                    } catch (Exception e) {
                        changedFiles = sh(script: "git diff --name-only \$(git rev-list --max-parents=0 HEAD) HEAD", returnStdout: true).trim().split("\n")
                    }
                    echo "Changed files: ${changedFiles}"

                    def changedServices = []
                    services.each { service ->
                        def serviceFolder = "spring-petclinic-${service}"
                        if (changedFiles.any { file -> file.startsWith(serviceFolder) }) {
                            changedServices << service
                            echo "Detected changes in service: ${service}"
                        }
                    }

                    if (changedServices.isEmpty()) {
                        echo "No changes detected in any service folder. Skipping build and push."
                    } else {
                        env.CHANGED_SERVICES = changedServices.join(',')
                    }
                }
            }
        }
        stage('Build and Push Feature Images') {
            when {
                allOf {
                    not { branch 'main' }
                    expression { env.CHANGED_SERVICES != null && env.CHANGED_SERVICES != '' }
                }
            }
            steps {
                script {
                    def changedServices = env.CHANGED_SERVICES.split(',').toList()
                    withCredentials([usernamePassword(
                        credentialsId: 'dockerhub-credentials-id',
                        usernameVariable: 'DOCKER_USER',
                        passwordVariable: 'DOCKER_PASS'
                    )]) {
                        sh 'docker login -u $DOCKER_USER -p $DOCKER_PASS'
                        changedServices.each { serviceName ->
                            def imageTag = "${DOCKERHUB_REPO}/spring-petclinic-${serviceName}:${COMMIT_ID}"
                            sh 'mvn clean package -pl spring-petclinic-' + serviceName + ' -am -q'
                            sh 'docker build -f Dockerfile.common -t ' + imageTag + ' ./spring-petclinic-' + serviceName
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
