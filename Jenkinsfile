pipeline {
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
    }

    parameters {
        booleanParam(
            name: 'RUN_TERRAFORM_APPLY',
            defaultValue: false,
            description: 'Run terraform apply before deploy (requires AWS credentials on the agent)'
        )
        string(
            name: 'EC2_HOST_OVERRIDE',
            defaultValue: '',
            description: 'Optional EC2 public IP. Leave empty to use terraform output instance_public_ip'
        )
        string(
            name: 'GIT_BRANCH',
            defaultValue: 'main',
            description: 'Branch to deploy on the EC2 host'
        )
    }

    environment {
        AWS_DEFAULT_REGION = 'ap-south-1'
        ANSIBLE_USER       = 'ubuntu'
        GIT_REPO_URL       = 'https://github.com/jaanu2003/devops-project.git'
        APP_DEPLOY_BRANCH  = "${params.GIT_BRANCH}"
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Validate') {
            steps {
                sh '''
                    python3 -m py_compile app.py
                    cd terraform && terraform init -backend=false && terraform validate
                '''
            }
        }

        stage('Terraform Apply') {
            when {
                expression { return params.RUN_TERRAFORM_APPLY }
            }
            steps {
                withCredentials([
                    string(credentialsId: 'aws-access-key-id', variable: 'AWS_ACCESS_KEY_ID'),
                    string(credentialsId: 'aws-secret-access-key', variable: 'AWS_SECRET_ACCESS_KEY')
                ]) {
                    sh '''
                        cd terraform
                        terraform init
                        terraform apply -auto-approve
                    '''
                }
            }
        }

        stage('Deploy to EC2') {
            steps {
                withCredentials([
                    sshUserPrivateKey(
                        credentialsId: 'devops-ec2-ssh-key',
                        keyFileVariable: 'SSH_KEY_FILE',
                        usernameVariable: 'SSH_USER'
                    )
                ]) {
                    script {
                        env.SSH_KEY_PATH = SSH_KEY_FILE
                        env.ANSIBLE_USER = SSH_USER
                        if (params.EC2_HOST_OVERRIDE?.trim()) {
                            env.EC2_HOST = params.EC2_HOST_OVERRIDE.trim()
                        }
                    }
                    script {
                        if (isUnix()) {
                            sh '''
                                bash scripts/generate_inventory.sh
                                cd ansible
                                ansible-playbook -i inventory deploy.yml
                            '''
                        } else {
                            def host = env.EC2_HOST ?: '13.126.236.86'
                            bat """
                                wsl bash -lc "export EC2_HOST=${host} APP_DEPLOY_BRANCH=${params.GIT_BRANCH} && cd /mnt/e/Jahnavi/Main/devops-project && cp \"\$(wslpath -u '%SSH_KEY_FILE%')\" ~/.ssh/devops-key.pem && bash scripts/wsl-ssh-setup.sh ~/.ssh/devops-key.pem && export SSH_KEY_PATH=~/.ssh/devops-key.pem && bash scripts/generate_inventory.sh && cd ansible && ansible-playbook -i inventory deploy.yml"
                            """
                        }
                    }
                }
            }
        }
    }

    post {
        success {
            script {
                def ip = params.EC2_HOST_OVERRIDE?.trim()
                if (!ip) {
                    ip = sh(
                        script: 'cd terraform && terraform output -raw instance_public_ip',
                        returnStdout: true
                    ).trim()
                }
                echo "Application URL: http://${ip}:5000"
            }
        }
    }
}
