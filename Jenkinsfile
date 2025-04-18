pipeline {
    agent any

    parameters {
        choice(name: 'JOB_TYPE', choices: ['none', 'developer_build', 'developer_build_manual_deletion'], description: 'Select job type for manual build')
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

                    if (isTagBuild) {
                        env.JENKINSFILE_PATH = "staging/Jenkinsfile"
                        env.TRIGGER_TYPE = "staging"
                    } else if (isNonMainBranch) {
                        env.JENKINSFILE_PATH = "dev/Jenkinsfile"
                        env.TRIGGER_TYPE = "dev"
                    } else if (isManualBuild) {
                        env.JENKINSFILE_PATH = "${params.JOB_TYPE}/Jenkinsfile"
                        env.TRIGGER_TYPE = params.JOB_TYPE
                    } else {
                        echo "No job triggered. Push to main without tag or invalid trigger."
                        env.JENKINSFILE_PATH = ""
                        env.TRIGGER_TYPE = "none"
                        return 
                    }

                    echo "Selected Jenkinsfile: ${env.JENKINSFILE_PATH}, Trigger: ${env.TRIGGER_TYPE}"
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
                            def jenkinsfileContent = readFile(file: env.JENKINSFILE_PATH)
                            echo "Loaded Jenkinsfile: ${env.JENKINSFILE_PATH}"
                        }
                    }
                }
            }
        }

        stage('Run Selected Pipeline') {
            when { expression { env.JENKINSFILE_PATH != "" } }
            steps {
                script {
                    dir('jenkins-config') {
                        load env.JENKINSFILE_PATH
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
