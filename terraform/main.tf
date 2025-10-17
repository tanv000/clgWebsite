# -----------------------------------------------------------------
# AWS Provider Configuration
# -----------------------------------------------------------------
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# -----------------------------------------------------------------
# 1. ECR (Elastic Container Registry) Repository
# -----------------------------------------------------------------
resource "aws_ecr_repository" "app_repo" {
  name                 = var.ecr_repo_name
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

output "ecr_repository_url" {
  value = aws_ecr_repository.app_repo.repository_url
}

# -----------------------------------------------------------------
# 2. Security Group (Firewall)
# -----------------------------------------------------------------
resource "aws_security_group" "web_sg" {
  name        = "web-server-sg"
  description = "Allow HTTP and SSH inbound traffic"

  # Ingress (Inbound) Rules
  ingress {
    description = "HTTP access from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH access from anywhere (Restrict this in production!)"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Egress (Outbound) Rule
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Web-SG"
  }
}

# -----------------------------------------------------------------
# 3. EC2 Instance (Docker Host)
# -----------------------------------------------------------------
resource "aws_instance" "web_app_host" {
  ami           = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_pair_name
  vpc_security_group_ids = [aws_security_group.web_sg.id]

  # User data to install Docker and Nginx on first boot
  user_data = <<-EOF
              #!/bin/bash
              # Update the system
              sudo yum update -y
              # Install Docker
              sudo amazon-linux-extras install docker -y
              sudo systemctl start docker
              sudo systemctl enable docker
              # Add ec2-user to docker group so we can run docker commands without sudo
              sudo usermod -aG docker ec2-user
              # Create a deployment script for Jenkins to use
              echo '#!/bin/bash
              # Log into ECR (replace region and repo with actual values)
              $(aws ecr get-login-password --region ${var.aws_region}) | docker login --username AWS --password-stdin ${aws_ecr_repository.app_repo.repository_url}
              
              # Pull the latest image (Jenkins will pass the TAG)
              IMAGE_TAG="$1"
              IMAGE_REPO_URL="${aws_ecr_repository.app_repo.repository_url}"

              # Stop and remove the old container
              docker stop web-app-container || true
              docker rm web-app-container || true

              # Run the new container
              docker run -d -p 80:80 --name web-app-container $IMAGE_REPO_URL:$IMAGE_TAG
              ' | sudo tee /usr/local/bin/deploy.sh
              sudo chmod +x /usr/local/bin/deploy.sh

              # Install AWS CLI V2 (needed for ECR login)
              sudo yum install -y unzip
              curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
              unzip awscliv2.zip
              sudo ./aws/install
              
              echo "Setup complete. Docker and AWS CLI installed."
              EOF

  tags = {
    Name = "Jenkins-Web-App-Host"
  }
}

output "web_app_public_ip" {
  value = aws_instance.web_app_host.public_ip
}
