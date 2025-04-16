def SERVICES_CHANGED = ""
def DEPLOY_ENV = "${params.ENVIRONMENT ?: 'staging'}" // Default is staging for main
pipeline {
    agent any

    triggers {
        githubPush()
    }

    environment {
        DOCKERHUB_REPO = 'csc11007'
        COMMIT_ID = "${env.GIT_COMMIT?.take(7) ?: ''}"
    }

    stages {
        stage('Detect Changes - Main Branch') {
            when {
                branch 'main'
            }
            steps {
                script {
                    echo "Checking if the repository is shallow..."
                    def isShallow = sh(script: "git rev-parse --is-shallow-repository", returnStdout: true).trim()
                    echo "Repository is shallow: ${isShallow}"

                    if (isShallow == "true") {
                        echo "Repository is shallow. Fetching full history..."
                        sh 'git fetch origin main --prune --unshallow --tags'
                    } else {
                        echo "Repository is already complete. Skipping --unshallow."
                        sh 'git fetch origin main --prune --tags'
                    }

                    echo "Fetching all branches and tags..."
                    sh 'git fetch --all --prune --tags'

                    // Check for new tags
                    def latestTag = sh(script: "git tag --sort=-creatordate | head -n 1", returnStdout: true).trim()
                    def currentCommit = sh(script: "git rev-parse HEAD", returnStdout: true).trim()
                    def tagCommit = latestTag ? sh(script: "git rev-list -n 1 ${latestTag}", returnStdout: true).trim() : ""

                    def isTagBuild = (latestTag && tagCommit == currentCommit)
                    env.TAG_NAME = isTagBuild ? latestTag : ""
                    echo "Latest tag: ${latestTag}, Tag commit: ${tagCommit}, Current commit: ${currentCommit}, Is tag build: ${isTagBuild}"

                    // Detect changed services
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

                    if (changedServices.isEmpty() && !isTagBuild) {
                        echo "No relevant services changed and no new tag. Skipping build."
                        SERVICES_CHANGED = ""
                    } else {
                        SERVICES_CHANGED = isTagBuild ? services.join(',') : changedServices.join(',')
                        echo "Services to process: ${SERVICES_CHANGED}"
                    }
                }
            }
        }

        stage('Detect Changed Services - Feature Branch') {
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
                        SERVICES_CHANGED = changedServices.join(',')
                        env.CHANGED_SERVICES = SERVICES_CHANGED
                    }
                }
            }
        }

        stage('Build Main Branch Services') {
            when {
                allOf {
                    branch 'main'
                    expression { SERVICES_CHANGED?.trim() != "" }
                }
            }
            steps {
                script {
                    def servicesList = SERVICES_CHANGED.tokenize(',')

                    if (servicesList.isEmpty()) {
                        echo "No services to build. Skipping."
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

        stage('Build & Push Main Branch Images') {
            when {
                allOf {
                    branch 'main'
                    expression { SERVICES_CHANGED?.trim() != "" }
                }
            }
            steps {
                script {
                    def servicesList = SERVICES_CHANGED.tokenize(',')
                    def isTagBuild = env.TAG_NAME?.trim() != ""

                    if (servicesList.isEmpty()) {
                        error("No services to build. Verify 'Detect Changes' stage.")
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
                        def tag = isTagBuild ? "main_${env.TAG_NAME}" : "main"
                        def imageTag = "csc11007/${service}:${tag}"

                        sh """
                        docker build \\
                            --build-arg SERVICE_NAME=${shortServiceName} \\
                            --build-arg EXPOSED_PORT=${servicePort} \\
                            -f Dockerfile \\
                            -t ${imageTag} \\
                            .
                        docker push ${imageTag}
                        docker rmi ${imageTag} || true
                        """
                    }
                }
            }
        }

        stage('Update GitOps Repository') {
            when {
                allOf {
                    branch 'main'
                    expression { SERVICES_CHANGED?.trim() != "" }
                }
            }
            steps {
                script {
                    def servicesList = SERVICES_CHANGED.tokenize(',')
                    def isTagBuild = env.TAG_NAME?.trim() != ""
                    def tag = isTagBuild ? "main_${env.TAG_NAME}" : "main"

                    sh "rm -rf spring-pet-clinic-microservices-configuration || true"

                    withCredentials([usernamePassword(
                        credentialsId: 'github-token',
                        usernameVariable: 'GIT_USERNAME',
                        passwordVariable: 'GIT_PASSWORD'
                    )]) {
                        sh '''
                        git clone https://$GIT_USERNAME:$GIT_PASSWORD@github.com/csc11007-assignments/spring-pet-clinic-microservices-configuration.git
                        '''

                        dir('spring-pet-clinic-microservices-configuration') {
                            def valuesFile = isTagBuild ? "charts/staging/values.yaml" : "charts/dev/values.yaml"
                            
                            for (service in servicesList) {
                                def shortServiceName = service.replaceFirst("spring-petclinic-", "")
                                sh """
                                if [ -f "${valuesFile}" ]; then
                                    echo "Updating image tag for ${shortServiceName} in ${valuesFile}"
                                    lineNumber=\$(grep -n "^[[:space:]]*${shortServiceName}:" ${valuesFile} | cut -d':' -f1)
                                    if [ ! -z "\$lineNumber" ]; then
                                        tagLine=\$((lineNumber + 3))
                                        sed -i "\${tagLine}s/tag: .*/tag: ${tag}/" ${valuesFile}
                                    fi
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
                                git commit -m "Update image tags for ${SERVICES_CHANGED} to ${tag}"
                                git push origin main
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

        stage('Build and Push Feature Branch Images') {
            when {
                allOf {
                    not { branch 'main' }
                    expression { SERVICES_CHANGED != null && SERVICES_CHANGED != '' }
                }
            }
            steps {
                script {
                    def changedServices = SERVICES_CHANGED.split(',').toList()
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
                        mvn clean package -pl spring-petclinic-${serviceName} -am -q -B -DskipTests
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
            sh 'docker system prune -f'
        }
    }
}
