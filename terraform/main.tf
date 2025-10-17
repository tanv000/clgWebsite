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
              
              # Update system and install Docker
              sudo yum update -y
              sudo yum install -y docker
              sudo systemctl start docker
              sudo systemctl enable docker
              
              # Allow ec2-user to run docker commands without sudo
              sudo usermod -aG docker ec2-user
              
              # Install AWS CLI V2 (needed for ECR login)
              sudo yum install -y unzip
              curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
              unzip awscliv2.zip
              sudo ./aws/install

              # CRITICAL: Add paths to .bashrc to ensure they load for ec2-user
              # We expect aws to be in /usr/local/bin/ and docker in /usr/bin/
              # The 'which' command failed because the environment isn't loading correctly.
              # We will add a path export to the ec2-user's profile to fix this.
              echo 'export PATH=$PATH:/usr/local/bin:/usr/bin' >> /home/ec2-user/.bashrc
              sudo chown ec2-user:ec2-user /home/ec2-user/.bashrc

              echo "Setup complete. Docker and AWS CLI installed."
              EOF

  tags = {
    Name = "Jenkins-Web-App-Host"
  }
}

output "web_app_public_ip" {
  value = aws_instance.web_app_host.public_ip
}
