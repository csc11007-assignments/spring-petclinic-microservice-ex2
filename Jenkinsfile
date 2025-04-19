pipeline {
    agent any

    parameters {
        choice(name: 'JOB_TYPE', choices: ['none', 'staging'], description: 'Select job type for manual build')
        string(name: 'tag_name', defaultValue: '', description: 'Git tag for staging (required for manual staging build)')
    }

    triggers {
        githubPush()
    }

    stages {
        stage('Determine Trigger and Job') {
            steps {
                script {
                    // Lấy nhánh từ GIT_BRANCH hoặc BRANCH_NAME
                    def branch = env.GIT_BRANCH ?: env.BRANCH_NAME ?: sh(script: "git rev-parse --abbrev-ref HEAD", returnStdout: true).trim()
                    if (branch.startsWith('origin/')) {
                        branch = branch.replace('origin/', '')
                    }
                    echo "Detected branch: ${branch}"
                    echo "Webhook payload: GIT_COMMIT=${env.GIT_COMMIT}, GIT_BRANCH=${env.GIT_BRANCH}, BRANCH_NAME=${env.BRANCH_NAME}"

                    def isTagBuild = env.GIT_REF?.startsWith("refs/tags/") ?: false
                    def isMainBranch = branch == "main"
                    def isDevBranch = branch == "dev"
                    def isFeatureBranch = !isMainBranch && !isDevBranch && branch != "" && !isTagBuild
                    def isManualBuild = params.JOB_TYPE != 'none'

                    env.TAG_NAME = isTagBuild ? env.GIT_REF.replace("refs/tags/", "") : ""
                    env.BRANCH_NAME = branch

                    echo "IsTagBuild: ${isTagBuild}, IsMainBranch: ${isMainBranch}, IsDevBranch: ${isDevBranch}, IsFeatureBranch: ${isFeatureBranch}, IsManualBuild: ${isManualBuild}"
                    echo "TAG_NAME: ${env.TAG_NAME}, BRANCH_NAME: ${env.BRANCH_NAME}, JOB_TYPE: ${params.JOB_TYPE}"

                    if (isManualBuild) {
                        if (params.JOB_TYPE == 'staging' && !params.tag_name?.trim()) {
                            error "tag_name is required for manual staging build"
                        }
                        env.JENKINSFILE_PATH = "${params.JOB_TYPE}/Jenkinsfile"
                        env.TRIGGER_TYPE = params.JOB_TYPE
                        env.PIPELINE_FUNC = "runStagingPipeline"
                    } else if (isTagBuild || isMainBranch) {
                        env.JENKINSFILE_PATH = "staging/Jenkinsfile"
                        env.TRIGGER_TYPE = "staging"
                        env.PIPELINE_FUNC = "runStagingPipeline"
                    } else if (isDevBranch) {
                        env.JENKINSFILE_PATH = "dev/Jenkinsfile"
                        env.TRIGGER_TYPE = "dev"
                        env.PIPELINE_FUNC = "runDevPipeline"
                    } else if (isFeatureBranch) {
                        env.JENKINSFILE_PATH = "features/Jenkinsfile"
                        env.TRIGGER_TYPE = "feature"
                        env.PIPELINE_FUNC = "runFeaturePipeline"
                    } else {
                        echo "No job triggered. Invalid branch: ${branch}"
                        env.JENKINSFILE_PATH = ""
                        env.TRIGGER_TYPE = "none"
                        env.PIPELINE_FUNC = ""
                        currentBuild.result = 'SUCCESS'
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
