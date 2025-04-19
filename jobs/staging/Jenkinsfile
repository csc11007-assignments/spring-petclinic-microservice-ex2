pipeline {
    agent any
    
    parameters {
        string(name: 'tag_name', defaultValue: '', description: 'Git tag from webhook')
    }

    environment {
        NAMESPACE = "staging"
        DOCKER_REGISTRY = 'csc11007'
        APP_NAME = "petclinic-${NAMESPACE}"
        GITOPS_REPO = "https://github.com/csc11007-assignments/spring-pet-clinic-microservices-configuration.git"
        VALUES_FILE = "charts/staging/values.yaml"
        COMMIT = "${params.tag_name?.trim()}" 
    }

    stages {
        stage('Validate tag') {
            steps {
                script {
                    def GIT_TAG = params.tag_name?.trim()
                    echo "Webhook tag_name: ${params.tag_name}"
                    echo "GIT_TAG: ${GIT_TAG}"
                    
                    if (!GIT_TAG) {
                        error "No tag provided. This job only runs for tag pushes."
                    }
                    
                    // Validate the tag format (should be like v1.2.3)
                    if (!(GIT_TAG ==~ /^v\d+\.\d+\.\d+$/)) {
                        error "Invalid tag format. Expected format: vX.Y.Z (e.g., v1.2.3)"
                    }
                }
            }
        }

        stage('Checkout Repository and Create Tag if Needed') {
            steps {
                script {
                    def GIT_TAG = params.tag_name?.trim()
                    
                    // Checkout main branch
                    sh "git fetch --all"
                    sh "git checkout main"
                    
                    // Check if tag exists
                    def tagExists = sh(script: "git tag -l ${GIT_TAG}", returnStdout: true).trim()
                    
                    // If tag doesn't exist, create it
                    if (!tagExists) {
                        withCredentials([usernamePassword(
                            credentialsId: 'github-token', 
                            usernameVariable: 'GIT_USERNAME', 
                            passwordVariable: 'GIT_PASSWORD'
                        )]) {
                            sh """
                                git config user.email "jenkins@example.com"
                                git config user.name "Jenkins CI"
                                git tag -a ${GIT_TAG} -m "Release tag ${GIT_TAG} created by Jenkins"
                                git push https://${GIT_USERNAME}:${GIT_PASSWORD}@github.com/csc11007-assignments/spring-petclinic-microservice-ex2.git ${GIT_TAG}
                                echo "Created new tag: ${GIT_TAG}"
                            """
                        }
                    } else {
                        echo "Tag ${GIT_TAG} already exists, using existing tag"
                    }
                    
                    // Checkout the tag
                    sh "git checkout tags/${GIT_TAG}"
                }
            }
        }

        stage('Create Release Branch') {
            steps {
                script {
                    def GIT_TAG = params.tag_name?.trim()
                    def RELEASE_BRANCH = "rc_${GIT_TAG}"
                    
                    withCredentials([usernamePassword(
                        credentialsId: 'github-token', 
                        usernameVariable: 'GIT_USERNAME', 
                        passwordVariable: 'GIT_PASSWORD'
                    )]) {
                        sh """
                            git config user.email "jenkins@example.com"
                            git config user.name "Jenkins CI"
                            
                            # Create release branch if it doesn't exist
                            if ! git ls-remote --heads origin ${RELEASE_BRANCH} | grep -q ${RELEASE_BRANCH}; then
                                git checkout -b ${RELEASE_BRANCH}
                                git push https://${GIT_USERNAME}:${GIT_PASSWORD}@github.com/csc11007-assignments/spring-petclinic-microservice-ex2.git ${RELEASE_BRANCH}
                                echo "Created release branch: ${RELEASE_BRANCH}"
                            else
                                echo "Release branch ${RELEASE_BRANCH} already exists"
                                git checkout ${RELEASE_BRANCH}
                            fi
                        """
                    }
                }
            }
        }

        stage('Build & Push docker images') {
            steps {
                script {
                    def serviceMap = [
                        'config-server': '8888',
                        'discovery-server': '8761',
                        'customers-service': '8081',
                        'visits-service': '8082',
                        'vets-service': '8083',
                        'genai-service': '8084',
                        'api-gateway': '8080',
                        'admin-server': '9090'
                    ]

                    withCredentials([usernamePassword(
                        credentialsId: 'csc11007',
                        usernameVariable: 'DOCKERHUB_USER',
                        passwordVariable: 'DOCKERHUB_PASSWORD'
                        )]) {
                        sh "echo ${DOCKERHUB_PASSWORD} | docker login -u ${DOCKERHUB_USER} --password-stdin"
                    }

                    serviceMap.each { service, port ->
                        def imageName = "${DOCKER_REGISTRY}/spring-petclinic-${service}:${params.tag_name}"
                        echo "Building Docker image for ${service} → ${imageName}"
                        
                        def moduleName = "spring-petclinic-${service}"
                        
                        sh """
                            docker build \
                              --build-arg SERVICE_NAME=${moduleName} \
                              --build-arg EXPOSED_PORT=${port} \
                              -t ${imageName} .
                        """
                        sh "docker push ${imageName}"
                    }

                    sh "docker logout"
                }
            }
        }

        stage('Checkout GitOps configuration repository') {
            steps {
                dir('gitops-repo') {
                    script {
                        withCredentials([usernamePassword(
                            credentialsId: 'github-token', 
                            usernameVariable: 'GIT_USERNAME', 
                            passwordVariable: 'GIT_PASSWORD'
                            )]) {
                            sh """
                                git clone https://${GIT_USERNAME}:${GIT_PASSWORD}@github.com/csc11007-assignments/spring-pet-clinic-microservices-configuration.git .
                                git config user.email "jenkins@example.com"
                                git config user.name "Jenkins CI"
                            """
                        }
                    }
                }
            }
        }

        stage('Update configuration with new image tags') {
            steps {
                dir('gitops-repo') {
                    script {
                        def tag = params.tag_name?.trim()
                        def services = [
                            'config-server',
                            'customers-service',
                            'discovery-server',
                            'visits-service',
                            'vets-service',
                            'genai-service',
                            'api-gateway',
                            'admin-server'
                        ]

                        services.each { svc ->
                            sh """
                                if grep -q "^[[:space:]]*${svc}:" ${VALUES_FILE}; then
                                    lineNumber=\$(grep -n "^[[:space:]]*${svc}:" ${VALUES_FILE} | cut -d':' -f1)
                                    if [ ! -z "\$lineNumber" ]; then
                                        tagLine=\$((lineNumber + 3))
                                        sed -i "\${tagLine}s/tag: .*/tag: ${tag}/" ${VALUES_FILE}
                                    fi
                                fi
                            """
                        }
                        
                        sh "cat ${VALUES_FILE}"
                    }
                }
            }
        }
    
        stage('Commit and Push to GitOps Repository') {
            steps {
                dir('gitops-repo') {
                    script {
                        withCredentials([usernamePassword(
                            credentialsId: 'github-token', 
                            usernameVariable: 'GIT_USERNAME', 
                            passwordVariable: 'GIT_PASSWORD'
                            )]) {
                            sh """
                                git add ${VALUES_FILE}
                                git commit -m "Update image tags for services to ${env.COMMIT}" || echo "No changes to commit"
                                git push origin main
                            """
                        }
                    }
                }
            }
        }
    }
    
    post {
        always {
            cleanWs()
        }
        success {
            echo "Successfully updated GitOps configuration repository"
        }
        failure {
            echo "Failed to update GitOps configuration repository"
        }
    }
}
