pipeline {
    agent any

    environment {
        IMAGE_NAME = "website"
        ECR_REPO   = "708972351530.dkr.ecr.ap-south-1.amazonaws.com/website"
        REGION     = "ap-south-1"
        AWS_CLI    = "C:\\Program Files\\Amazon\\AWSCLI\\bin\\aws.exe"
        TERRAFORM  = "C:\\Terraform\\terraform.exe"
    }

    stages {
        stage('Clone Repository') {
            steps {
                echo 'Cloning repository...'
            }
        }

        stage('Build Docker Image') {
            steps {
                echo ' Building Docker image...'
                bat 'docker build -t %IMAGE_NAME%:latest .'
            }
        }

        stage('Push to AWS ECR') {
            steps {
                echo ' Pushing image to AWS ECR...'
                withCredentials([usernamePassword(credentialsId: 'AWS_ECR_CREDENTIALS', usernameVariable: 'AWS_ACCESS_KEY_ID', passwordVariable: 'AWS_SECRET_ACCESS_KEY')]) {
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

        stage('Deploy with Terraform') {
            steps {
                echo ' Deploying EC2 instance and running Docker container...'
                withCredentials([usernamePassword(credentialsId: 'AWS_ECR_CREDENTIALS', usernameVariable: 'AWS_ACCESS_KEY_ID', passwordVariable: 'AWS_SECRET_ACCESS_KEY')]) {
                    dir('terraform') {
                        bat """
                        set AWS_ACCESS_KEY_ID=%AWS_ACCESS_KEY_ID%
                        set AWS_SECRET_ACCESS_KEY=%AWS_SECRET_ACCESS_KEY%
                        "%TERRAFORM%" init
                        "%TERRAFORM%" apply -auto-approve
                        """
                    }
                }
            }
        }

        
    }

    post {
        success {
            echo 'Docker image pushed, EC2 deployed, and website is running!'
            echo 'Open the site in your browser using the EC2 Public IP or DNS.'
        }
        failure {
            echo ' Build or deployment failed!'
        }
    }
}
