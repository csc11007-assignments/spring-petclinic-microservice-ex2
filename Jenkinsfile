def SERVICES_CHANGED = ""
def DEPLOY_ENV = "${params.ENVIRONMENT ?: 'dev'}" // Default is dev if not specified
pipeline {
    agent any

    stages {
        stage('Detect Changes') {
            steps {
                script {
                    echo "Checking if the repository is shallow..."
                    def isShallow = sh(script: "git rev-parse --is-shallow-repository", returnStdout: true).trim()
                    echo "Repository is shallow: ${isShallow}"

                    if (isShallow == "true") {
                        echo "Repository is shallow. Fetching full history..."
                        sh 'git fetch origin main --prune --unshallow'
                    } else {
                        echo "Repository is already complete. Skipping --unshallow."
                        sh 'git fetch origin main --prune'
                    }

                    echo "Fetching all branches..."
                    sh 'git fetch --all --prune'

                    echo "Checking if origin/main exists..."
                    def mainExists = sh(script: "git branch -r | grep 'origin/main' || echo ''", returnStdout: true).trim()
                    echo "Main branch exists: ${mainExists}"

                    if (!mainExists) {
                        echo "origin/main does not exist in remote. Fetching all branches..."
                        sh 'git remote set-branches --add origin main'
                        sh 'git fetch --all'

                        mainExists = sh(script: "git branch -r | grep 'origin/main' || echo ''", returnStdout: true).trim()
                        echo "Main branch exists: ${mainExists}"
                        if (!mainExists) {
                            error("origin/main still does not exist!")
                        }
                    }

                    // Use previous commit instead of merge-base for change detection
                    def baseCommit
                    if (env.GIT_PREVIOUS_SUCCESSFUL_COMMIT) {
                        baseCommit = env.GIT_PREVIOUS_SUCCESSFUL_COMMIT
                        echo "Using previous successful commit: ${baseCommit}"
                    } else {
                        baseCommit = sh(script: "git rev-parse HEAD~1", returnStdout: true).trim()
                        echo "Using previous commit: ${baseCommit}"
                    }

                    def changes = sh(script: "git diff --name-only ${baseCommit} HEAD", returnStdout: true).trim()
                    echo "Raw changed files:\n${changes}"

                    def changedFiles = changes ? changes.split("\n") : []
                    def normalizedChanges = changedFiles.collect { file ->
                        file.replaceFirst("^.*?/spring-petclinic-microservices/", "")
                    }

                    echo "Normalized changed files: ${normalizedChanges.join(', ')}"

                    def services = [
                        "spring-petclinic-admin-server",
                        "spring-petclinic-api-gateway",
                        "spring-petclinic-config-server",
                        "spring-petclinic-customers-service",
                        "spring-petclinic-discovery-server",
                        "spring-petclinic-genai-service",
                        "spring-petclinic-vets-service",
                        "spring-petclinic-visits-service",
                    ]

                    def changedServices = services.findAll { service ->
                        normalizedChanges.any { file ->
                            file.startsWith("${service}/") || file.contains("${service}/")
                        }
                    }

                    echo "Final changed services list: ${changedServices.join(', ')}"

                    if (changedServices.isEmpty()) {
                        echo "No relevant services changed. Skipping tests, build, and image creation."
                        SERVICES_CHANGED = "" // Explicitly set to empty to skip later stages
                    } else {
                        // Use properties() to persist the value
                        properties([
                            parameters([
                                string(name: 'SERVICES_CHANGED', defaultValue: changedServices.join(','), description: 'Services that changed in this build')
                            ])
                        ])

                        SERVICES_CHANGED = changedServices.join(',')
                        echo "Services changed (Global ENV): ${SERVICES_CHANGED}"
                    }
                }
            }
        }

        stage('Build (Maven)') {
            when {
                expression { SERVICES_CHANGED?.trim() != "" }
            }
            steps {
                script {
                    def servicesList = SERVICES_CHANGED.tokenize(',')

                    if (servicesList.isEmpty()) {
                        echo "No changed services found. Skipping build."
                        return
                    }

                    for (service in servicesList) {
                        echo "Building ${service}..."
                        dir(service) {
                            sh 'chmod +x ../mvnw'
                            sh '../mvnw package -DskipTests -T 1C'
                        }
                    }
                }
            }
        }

        stage('Build & push container images') {
            when {
                expression { SERVICES_CHANGED?.trim() != "" }
            }
            steps {
                script {
                    def servicesList = SERVICES_CHANGED.tokenize(',')

                    if (servicesList.isEmpty()) {
                        error("No changed services found. Verify 'Detect Changes' stage.")
                    }

                    def servicePorts = [
                        "spring-petclinic-admin-server": 9090,
                        "spring-petclinic-api-gateway": 8080,
                        "spring-petclinic-config-server": 8888,
                        "spring-petclinic-customers-service": 8081,
                        "spring-petclinic-discovery-server": 8761,
                        "spring-petclinic-genai-service": 8084,
                        "spring-petclinic-vets-service": 8083,
                        "spring-petclinic-visits-service": 8082
                    ]

                    withCredentials([usernamePassword(
                        credentialsId: 'csc11007',
                        usernameVariable: 'DOCKERHUB_USER',
                        passwordVariable: 'DOCKERHUB_PASSWORD'
                    )]) {
                        sh 'echo $DOCKERHUB_PASSWORD | docker login -u $DOCKERHUB_USER --password-stdin'
                    }

                    for (service in servicesList) {
                        echo "Building & pushing Docker image for ${service}..."

                        def shortServiceName = service.replaceFirst("spring-petclinic-", "")
                        def servicePort = servicePorts.get(service, 8080)
                        def commitHash = sh(script: "git rev-parse --short HEAD", returnStdout: true).trim()
                        def imageTag = "csc11007/${service}:${commitHash}"

                        sh """
                        docker build \\
                            --build-arg SERVICE_NAME=${shortServiceName} \\
                            --build-arg EXPOSED_PORT=${servicePort} \\
                            -f Dockerfile \\
                            -t ${imageTag} \\
                            -t csc11007/${service}:latest \\
                            .
                        docker push ${imageTag}
                        docker push csc11007/${service}:latest
                        docker rmi ${imageTag} || true
                        docker rmi csc11007/${service}:latest || true
                        """
                    }
                }
            }
        }

        stage('Update GitOps Repository') {
            when {
                expression { SERVICES_CHANGED?.trim() != "" }
            }
            steps {
                script {
                    def servicesList = SERVICES_CHANGED.tokenize(',')
                    def commitHash = sh(script: "git rev-parse --short HEAD", returnStdout: true).trim()

                    sh "rm -rf spring-pet-clinic-microservices-configuration || true"

                    withCredentials([usernamePassword(
                        credentialsId: 'github-token',
                        usernameVariable: 'GIT_USERNAME',
                        passwordVariable: 'GIT_PASSWORD'
                    )]) {
                        sh """
                        git clone https://github.com/csc11007-assignments/spring-pet-clinic-microservices-configuration.git
                        """

                        dir('spring-pet-clinic-microservices-configuration') {
                            for (service in servicesList) {
                                def shortServiceName = service.replaceFirst("spring-petclinic-", "")
                                def valuesFile = "values/dev/${shortServiceName}_values.yaml"

                                sh """
                                if [ -f "${valuesFile}" ]; then
                                    echo "Updating image tag in ${valuesFile}"
                                    sed -i 's/\\(tag:\\s*\\).*/\\1"'${commitHash}'"/' ${valuesFile}
                                else
                                    echo "Warning: ${valuesFile} not found"
                                fi
                                """
                            }

                            sh """
                            git config user.email "jenkins@example.com"
                            git config user.name "Jenkins CI"
                            git status

                            if ! git diff --quiet; then
                                git add .
                                git commit -m "Update image tags for ${SERVICES_CHANGED} to ${commitHash}"
                                git push
                                echo "Successfully updated GitOps repository"
                            else
                                echo "No changes to commit in GitOps repository"
                            fi
                            """
                        }
                    }

                    sh "rm -rf spring-pet-clinic-microservices-configuration || true"
                }
            }
        }
    }

    post {
        failure {
            script {
                echo "CI/CD Pipeline failed!"
            }
        }
        success {
            script {
                echo "CI/CD Pipeline succeeded!"
            }
        }
        always {
            echo "Pipeline execution completed for services: ${SERVICES_CHANGED}"
        }
    }
}
