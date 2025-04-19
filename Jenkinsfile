pipeline {
    agent any

    parameters {
        choice(name: 'JOB_TYPE', choices: ['none', 'staging', 'developer_build', 'developer_build_manual_deletion'], description: 'Select job type for manual build')
        string(name: 'config_server', defaultValue: '', description: 'Tag for config-server (required for developer_build)')
        string(name: 'discovery_server', defaultValue: '', description: 'Tag for discovery-server (required for developer_build)')
        string(name: 'customers_service', defaultValue: '', description: 'Tag for customers-service (required for developer_build)')
        string(name: 'visits_service', defaultValue: '', description: 'Tag for visits-service (required for developer_build)')
        string(name: 'vets_service', defaultValue: '', description: 'Tag for vets-service (required for developer_build)')
        string(name: 'genai_service', defaultValue: '', description: 'Tag for genai-service (required for developer_build)')
        string(name: 'api_gateway', defaultValue: '', description: 'Tag for api-gateway (required for developer_build)')
        string(name: 'admin_server', defaultValue: '', description: 'Tag for admin-server (required for developer_build)')
        string(name: 'JOB_NAME_TO_DELETE', defaultValue: '', description: 'Job name for manual deletion (required for developer_build_manual_deletion)')
        string(name: 'tag_name', defaultValue: '', description: 'Git tag for staging (required for manual staging build)')
    }

    triggers {
        githubPush()
    }

    stages {
        stage('Determine Trigger and Job') {
            steps {
                script {
                    def ref = env.GIT_REF ?: sh(script: "git rev-parse --symbolic-full-name HEAD", returnStdout: true).trim()
                    if (ref == "HEAD") {
                        ref = env.BRANCH_NAME ? "refs/heads/${env.BRANCH_NAME}" : sh(script: "git symbolic-ref HEAD", returnStdout: true).trim()
                    }
                    echo "Current ref: ${ref}"

                    def isTagBuild = ref.startsWith("refs/tags/")
                    def isMainBranch = ref == "refs/heads/main"
                    def isNonMainBranch = ref.startsWith("refs/heads/") && !isMainBranch
                    def isManualBuild = params.JOB_TYPE != 'none'

                    env.TAG_NAME = isTagBuild ? ref.replace("refs/tags/", "") : ""
                    env.BRANCH_NAME = ref.startsWith("refs/heads/") ? ref.replace("refs/heads/", "") : ""

                    echo "IsTagBuild: ${isTagBuild}, IsMainBranch: ${isMainBranch}, IsNonMainBranch: ${isNonMainBranch}, IsManualBuild: ${isManualBuild}"
                    echo "TAG_NAME: ${env.TAG_NAME}, BRANCH_NAME: ${env.BRANCH_NAME}, JOB_TYPE: ${params.JOB_TYPE}"

                    if (isManualBuild) {
                        if (params.JOB_TYPE == 'developer_build') {
                            def requiredParams = [
                                'config_server', 'discovery_server', 'customers_service',
                                'visits_service', 'vets_service', 'genai_service',
                                'api_gateway', 'admin_server'
                            ]
                            def missingParams = requiredParams.findAll { !params[it]?.trim() }
                            if (missingParams) {
                                error "Missing required parameters for developer_build: ${missingParams.join(', ')}"
                            }
                        } else if (params.JOB_TYPE == 'developer_build_manual_deletion') {
                            if (!params.JOB_NAME_TO_DELETE?.trim()) {
                                error "JOB_NAME_TO_DELETE is required for developer_build_manual_deletion"
                            }
                        } else if (params.JOB_TYPE == 'staging' && !params.tag_name?.trim()) {
                            error "tag_name is required for manual staging build"
                        }
                        env.JENKINSFILE_PATH = "${params.JOB_TYPE}/Jenkinsfile"
                        env.TRIGGER_TYPE = params.JOB_TYPE
                        env.PIPELINE_FUNC = params.JOB_TYPE == 'developer_build' ? "runDeveloperBuildPipeline" :
                                            params.JOB_TYPE == 'developer_build_manual_deletion' ? "runDeveloperBuildDeletionPipeline" :
                                            "runStagingPipeline"
                    } else if (isTagBuild || isMainBranch) {
                        env.JENKINSFILE_PATH = "staging/Jenkinsfile"
                        env.TRIGGER_TYPE = "staging"
                        env.PIPELINE_FUNC = "runStagingPipeline"
                    } else if (isNonMainBranch) {
                        env.JENKINSFILE_PATH = "dev/Jenkinsfile"
                        env.TRIGGER_TYPE = "dev"
                        env.PIPELINE_FUNC = "runDevPipeline"
                    } else {
                        echo "No job triggered. Push to main without tag or invalid trigger."
                        env.JENKINSFILE_PATH = ""
                        env.TRIGGER_TYPE = "none"
                        env.PIPELINE_FUNC = ""
                        return
                    }

                    echo "Selected Jenkinsfile: ${env.JENKINSFILE_PATH}, Trigger: ${env.TRIGGER_TYPE}, Function: ${env.PIPELINE_FUNC}"
                }
            }
        }

        stage('Checkout Jenkinsfile from Config Repo') {
            when { expression { env.JENKINSFILE_PATH != "" } }
            steps {
                script {
                    dir('jenkins-config') {
                        withCredentials([usernamePassword(
                            credentialsId: 'github-token',
                            usernameVariable: 'GIT_USERNAME',
                            passwordVariable: 'GIT_PASSWORD'
                        )]) {
                            git(
                                branch: 'main',
                                credentialsId: 'github-token',
                                url: 'https://github.com/csc11007-assignments/spring-petclinic-jenkins-configuration.git'
                            )
                            echo "Loaded Jenkinsfile: ${env.JENKINSFILE_PATH}"
                        }
                    }
                }
            }
        }

        stage('Run Selected Pipeline') {
            when { expression { env.JENKINSFILE_PATH != "" && env.PIPELINE_FUNC != "" } }
            steps {
                script {
                    dir('jenkins-config') {
                        def script = load env.JENKINSFILE_PATH
                        script."${env.PIPELINE_FUNC}"()
                    }
                }
            }
        }
    }

    post {
        always {
            cleanWs()
            echo "Pipeline completed. Trigger: ${env.TRIGGER_TYPE ?: 'none'}, Jenkinsfile: ${env.JENKINSFILE_PATH ?: 'none'}"
        }
        success {
            echo "Successfully executed ${env.TRIGGER_TYPE ?: 'none'} pipeline"
        }
        failure {
            echo "Failed to execute ${env.TRIGGER_TYPE ?: 'none'} pipeline"
        }
    }
}
