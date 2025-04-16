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
                    def servicePorts = [
                        'admin-server': 9090,
                        'api-gateway': 8080,
                        'config-server': 8888,
                        'customers-service': 8081,
                        'discovery-server': 8761,
                        'genai-service': 8084,
                        'vets-service': 8083,
                        'visits-service': 8082
                    ]
                    
                    withCredentials([usernamePassword(
                        credentialsId: 'csc11007',
                        usernameVariable: 'DOCKER_USER',
                        passwordVariable: 'DOCKER_PASS'
                    )]) {
                        sh 'echo $DOCKER_PASS | docker login -u $DOCKER_USER --password-stdin'
                    }
                    changedServices.each { serviceName ->
                        def imageTag = "${DOCKERHUB_REPO}/spring-petclinic-${serviceName}:${COMMIT_ID}"
                        def servicePort = servicePorts[serviceName]

                        sh """
                        mvn clean package -pl spring-petclinic-${serviceName} -am -q -B
                        docker build \\
                            --build-arg SERVICE_NAME=${serviceName} \\
                            --build-arg EXPOSED_PORT=${servicePort} \\
                            -f Dockerfile \\
                            -t ${imageTag} \\
                            .
                        docker push ${imageTag}
                        """
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
