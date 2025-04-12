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

                    // Fetch all branches to ensure latest changes
                    echo "Fetching all branches..."
                    sh 'git fetch --all --prune'

                    // Main branch has to exist
                    echo "Checking if origin/main exists..."
                    def mainExists = sh(script: "git branch -r | grep 'origin/main' || echo ''", returnStdout: true).trim()
                    echo "Main branch exists: ${mainExists}"

                    if (!mainExists) {
                        echo "origin/main does not exist in remote. Fetching all branches..."
                        sh 'git remote set-branches --add origin main'
                        sh 'git fetch --all'

                        // Create new main branch and check again
                        mainExists = sh(script: "git branch -r | grep 'origin/main' || echo ''", returnStdout: true).trim()
                        echo "Main branch exists: ${mainExists}"
                        if (!mainExists) {
                            error("origin/main still does not exist!")
                        }
                    }


                    // Get base commit to compare against
                    def baseCommit = sh(script: "git merge-base origin/main HEAD", returnStdout: true).trim()
                    echo "Base commit: ${baseCommit}"

                    // Base commit has to be valid
                    if (!baseCommit) {
                        error("Base commit not found! Ensure 'git merge-base origin/main HEAD' returns a valid commit.")
                    }

                    // Get the list of changed files relative to the base commit
                    def changes = sh(script: "git diff --name-only ${baseCommit} HEAD", returnStdout: true).trim()

                    echo "Raw changed files:\n${changes}"

                    // Changes have to be detected
                    if (!changes) {
                        echo "No changes detected. Skipping tests & build."
                        SERVICES_CHANGED = ""
                        return
                    }

                    // Convert the list into an array
                    def changedFiles = changes.split("\n")

                    // Normalize paths to ensure they match expected service directories
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

                    // Identify which services have changes
                    def changedServices = services.findAll { service ->
                        normalizedChanges.any { file ->
                            file.startsWith("${service}/") || file.contains("${service}/")
                        }
                    }

                    echo "Final changed services list: ${changedServices.join(', ')}"

                    // Ensure we have at least one changed service
                    if (changedServices.isEmpty()) {
                        echo "No relevant services changed. Skipping tests & build."
                        changedServices = services
                        //SERVICES_CHANGED = ""
                        //return
                    }

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

                    // Login to DockerHub once before the loop
                    withCredentials([usernamePassword(
                        credentialsId: 'csc11007',
                        usernameVariable: 'DOCKERHUB_USER',
                        passwordVariable: 'DOCKERHUB_PASSWORD'
                    )]) {
                        sh "docker login -u \${DOCKERHUB_USER} -p \${DOCKERHUB_PASSWORD}"
                    }

                    for (service in servicesList) {
                        echo "Building & pushing Docker image for ${service}..."

                        // Extract short service name from the full name
                        def shortServiceName = service.replaceFirst("spring-petclinic-", "")
                        
                        // Get the appropriate port for this service
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
                    
                    // Create a temporary directory for the GitOps repo

                    // Remove the existing directory if it exists
                    sh "rm -rf spring-pet-clinic-microservices-configuration || true"
                    
                    // Use credentials for Git operations
                    withCredentials([usernamePassword(
                        credentialsId: 'github-credentials', 
                        usernameVariable: 'GIT_USERNAME', 
                        passwordVariable: 'GIT_PASSWORD'
                    )]) {
                        // Clone with credentials
                        sh """
                        git clone https://git@github.com/csc11007-assignments/spring-pet-clinic-microservices-configuration.git
                        """
                        
                        dir('spring-pet-clinic-microservices-configuration') {
                            
                            // Update image tags for each changed service
                            for (service in servicesList) {
                                def shortServiceName = service.replaceFirst("spring-petclinic-", "")
                                def valuesFile = "values/dev/values-${shortServiceName}.yaml"
                                
                                // Check if file exists and update with sed
                                sh """
                                if [ -f "${valuesFile}" ]; then
                                    echo "Updating image tag in ${valuesFile}"
                                    sed -i 's/\\(tag:\\s*\\).*/\\1"'${commitHash}'"/' ${valuesFile}
                                else
                                    echo "Warning: ${valuesFile} not found"
                                fi
                                """
                            }
                            
                            // Configure Git and commit changes
                            sh """
                            git config user.email "jenkins@example.com"
                            git config user.name "Jenkins CI"
                            git status
                            
                            # Only commit if there are changes
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
                    
                    // Clean up after ourselves
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