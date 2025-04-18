pipeline {
    agent any

    environment {
        TAG_NAME = "${env.BUILD_NUMBER}-${env.GIT_COMMIT?.take(7)}"
        DOCKER_REGISTRY = 'csc11007'
        BRANCH_NAME = "${env.BRANCH_NAME}"
        COMMIT_ID = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Identify Changed Services') {
            steps {
                script {
                    def changedFiles = sh(script: "git diff --name-only ${env.GIT_COMMIT}^ ${env.GIT_COMMIT}", returnStdout: true)
                    def services = []
                    changedFiles.split('\n').each { file ->
                        def parts = file.split('/')
                        if (parts.size() > 0 && parts[0].startsWith("spring-petclinic-")) {
                            services.add(parts[0].replace("spring-petclinic-", ""))
                        }
                    }
                    services = services.unique()
                    echo "Services with changes: ${services.join(', ')}"
                    env.CHANGED_SERVICES = services.join(',')
                }
            }
        }

        // stage('Test & coverage') {
        //     when {
        //         expression { env.CHANGED_SERVICES != '' }
        //     }
        //     steps {
        //         script {
        //             def services = env.CHANGED_SERVICES.split(',')
        //             services.each { service ->
        //                 echo "Running tests for service: ${service}"
        //                 dir("spring-petclinic-${service}") {
        //                     sh "mvn clean test jacoco:report"
        //                     def zipName = "${service}-test-results-${env.TAG_NAME}.zip"
        //                     sh "zip -r ${zipName} target/surefire-reports/ target/site/jacoco/"
        //                     archiveArtifacts artifacts: "${zipName}", allowEmptyArchive: false

        //                     if (!fileExists("target/site/jacoco/jacoco.xml")) {
        //                         error("JaCoCo report not found!")
        //                     }

        //                     def xml = readFile("target/site/jacoco/jacoco.xml")
        //                     def totalMissed = 0.0, totalCovered = 0.0
        //                     def matches = (xml =~ /<counter type="INSTRUCTION" missed="([^"]*)" covered="([^"]*)"/)
        //                     matches.each { m ->
        //                         totalMissed += m[1].toFloat()
        //                         totalCovered += m[2].toFloat()
        //                     }

        //                     def coverage = totalCovered / (totalCovered + totalMissed)
        //                     if (coverage < 0.7) {
        //                         error("Coverage too low: ${(coverage*100).round(2)}%")
        //                     }
        //                     echo "Coverage OK: ${(coverage*100).round(2)}%"
        //                 }
        //             }
        //         }
        //     }
        // }

        stage('Build artifacts') {
            when {
                expression { env.CHANGED_SERVICES != '' }
            }
            steps {
                script {
                    def services = env.CHANGED_SERVICES.split(',')
                    services.each { service ->
                        echo "Packaging service: ${service}"
                        dir("spring-petclinic-${service}") {
                            sh "mvn clean package -DskipTests"
                            def jarName = "spring-petclinic-${service}-${env.TAG_NAME}.jar"
                            sh "mv target/spring-petclinic-${service}-*.jar target/${jarName}"
                            archiveArtifacts artifacts: "target/${jarName}", allowEmptyArchive: false
                        }
                    }
                }
            }
        }

        stage('Build & Push Docker images') {
            when {
                expression { env.CHANGED_SERVICES != '' }
            }
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

                    def imageTag = "${env.BRANCH_NAME}-${env.COMMIT_ID}"

                    def services = env.CHANGED_SERVICES.split(',')
                    services.each { service ->
                        def serviceName = "spring-petclinic-${service}"
                        def port = serviceMap[service]
                        if (!port) {
                            echo "Skipping unknown service: ${service}"
                            return
                        }
                        
                        echo "Building Docker for ${serviceName}"
                       sh """
                            docker build \
                            --build-arg SERVICE_NAME=${serviceName} \
                            --build-arg SERVICE_PORT=${port} \
                            -t ${DOCKER_REGISTRY}/${serviceName}:${imageTag} .
                        """
                        sh "docker push ${DOCKER_REGISTRY}/${serviceName}:${imageTag}"
                    }

                    sh 'docker logout'
                }
            }
        }
    }

    post {
        success {
            echo "Pipeline completed successfully!"
        }
        failure {
            echo "Pipeline failed. Check logs."
        }
        always {
            sh "docker system prune -f"
        }
    }
}
