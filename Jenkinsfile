pipeline {
    agent any

    environment {
        IMAGE_NAME = "website"
        REGION     = "ap-south-1"
        AWS_CLI    = "C:\\Program Files\\Amazon\\AWSCLI\\bin\\aws.exe"
        TERRAFORM  = "C:\\Terraform\\terraform.exe"
    }

    stages {

        stage('Clone Repository') {
            steps {
                echo 'Cloning repository...'
                git branch: 'main', url: 'https://github.com/tanv000/TravelScape-CI-CD-Implementation.git'
            }
        }

        stage('Provision ECR via Terraform') {
            steps {
                echo 'Provisioning AWS ECR Repository...'
                withCredentials([usernamePassword(credentialsId: 'AWS_ECR_CREDENTIALS', usernameVariable: 'AWS_ACCESS_KEY_ID', passwordVariable: 'AWS_SECRET_ACCESS_KEY')]) {
                    dir('terraform') {
                        bat """
                        set AWS_ACCESS_KEY_ID=%AWS_ACCESS_KEY_ID%
                        set AWS_SECRET_ACCESS_KEY=%AWS_SECRET_ACCESS_KEY%
                        "%TERRAFORM%" init
                        "%TERRAFORM%" apply -auto-approve -target=aws_ecr_repository.website
                        """
                    }
                }
            }
        }

        stage('Build Docker Image') {
            steps {
                echo 'Building Docker image...'
                bat 'docker build -t %IMAGE_NAME%:latest .'
            }
        }

        stage('Push to AWS ECR') {
            steps {
                echo 'Pushing image to ECR...'
                withCredentials([usernamePassword(credentialsId: 'AWS_ECR_CREDENTIALS', usernameVariable: 'AWS_ACCESS_KEY_ID', passwordVariable: 'AWS_SECRET_ACCESS_KEY')]) {
                    dir('terraform') {
                        script {
                            // Get ECR repo URL dynamically from Terraform output
                            def ecr_repo = bat(script: "\"%TERRAFORM%\" output -raw ecr_repo_url", returnStdout: true).trim()
                            env.ECR_REPO = ecr_repo
                        }
                    }

                    bat """
                    set AWS_ACCESS_KEY_ID=%AWS_ACCESS_KEY_ID%
                    set AWS_SECRET_ACCESS_KEY=%AWS_SECRET_ACCESS_KEY%
                    "%AWS_CLI%" ecr get-login-password --region %REGION% | docker login --username AWS --password-stdin %ECR_REPO%
                    docker tag %IMAGE_NAME%:latest %ECR_REPO%:latest
                    docker push %ECR_REPO%:latest
                    """
                }
            }
        }

        stage('Deploy EC2 with Terraform') {
            steps {
                echo 'Deploying EC2 instance and running Docker container...'
                withCredentials([usernamePassword(credentialsId: 'AWS_ECR_CREDENTIALS', usernameVariable: 'AWS_ACCESS_KEY_ID', passwordVariable: 'AWS_SECRET_ACCESS_KEY')]) {
                    dir('terraform') {
                        bat """
                        set AWS_ACCESS_KEY_ID=%AWS_ACCESS_KEY_ID%
                        set AWS_SECRET_ACCESS_KEY=%AWS_SECRET_ACCESS_KEY%
                        "%TERRAFORM%" apply -auto-approve
                        """
                    }
                }
            }
        }
    }

    post {
        success {
            echo '✅ Docker image pushed, EC2 deployed, and website running!'
            echo '🌐 Open the site using the EC2 Public IP or DNS from Terraform outputs.'
        }
        failure {
            echo '❌ Build or deployment failed!'
        }
    }
}
