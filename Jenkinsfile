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
                    echo "Current ref: ${ref}"

                    def isTagBuild = ref.startsWith("refs/tags/")
                    def isMainBranch = ref == "refs/heads/main"
                    def isNonMainBranch = ref.startsWith("refs/heads/") && !isMainBranch
                    def isManualBuild = params.JOB_TYPE != 'none'

                    env.TAG_NAME = isTagBuild ? ref.replace("refs/tags/", "") : ""
                    env.BRANCH_NAME = ref.startsWith("refs/heads/") ? ref.replace("refs/heads/", "") : ""

                    echo "IsTagBuild: ${isTagBuild}, IsMainBranch: ${isMainBranch}, IsNonMainBranch: ${isNonMainBranch}, IsManualBuild: ${isManualBuild}"
                    echo "TAG_NAME: ${env.TAG_NAME}, BRANCH_NAME: ${env.BRANCH_NAME}, JOB_TYPE: ${params.JOB_TYPE}"

                    if (isTagBuild && isMainBranch) {
                        env.JENKINSFILE_PATH = "staging/Jenkinsfile"
                        env.TRIGGER_TYPE = "staging"
                    } else if (isNonMainBranch) {
                        env.JENKINSFILE_PATH = "dev/Jenkinsfile"
                        env.TRIGGER_TYPE = "dev"
                    } else if (isManualBuild) {
                        env.JENKINSFILE_PATH = "${params.JOB_TYPE}/Jenkinsfile"
                        env.TRIGGER_TYPE = params.JOB_TYPE
                    } else {
                        error "No valid trigger detected. Tag push must be on main, branch push must be non-main, or manual build must specify JOB_TYPE."
                    }

                    echo "Selected Jenkinsfile: ${env.JENKINSFILE_PATH}, Trigger: ${env.TRIGGER_TYPE}"
                }
            }
        }

        stage('Checkout Jenkinsfile from Config Repo') {
            steps {
                script {
                    dir('jenkins-config') {
                        git branch: 'main', url: 'https://github.com/csc11007-assignments/spring-petclinic-jenkins-configuration.git'
                        def jenkinsfileContent = readFile(file: env.JENKINSFILE_PATH)
                        echo "Loaded Jenkinsfile: ${env.JENKINSFILE_PATH}"
                    }
                }
            }
        }

        stage('Run Selected Pipeline') {
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
            echo "Pipeline completed. Trigger: ${env.TRIGGER_TYPE}, Jenkinsfile: ${env.JENKINSFILE_PATH}"
        }
        success {
            echo "Successfully executed ${env.TRIGGER_TYPE} pipeline"
        }
        failure {
            echo "Failed to execute ${env.TRIGGER_TYPE} pipeline"
        }
    }
}
