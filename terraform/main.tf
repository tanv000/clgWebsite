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
  force_delete         = true # FIX: Allows deletion of repo with images

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
# 4. IAM Role for ECR Access (CRITICAL FIX)
# -----------------------------------------------------------------
resource "aws_iam_role" "ec2_ecr_role" {
  name = "ec2-ecr-role-${var.ecr_repo_name}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

# Attach the managed policy for ECR read-only access
resource "aws_iam_role_policy_attachment" "ecr_readonly_attach" {
  role       = aws_iam_role.ec2_ecr_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# -----------------------------------------------------------------
# 5. IAM Instance Profile (CRITICAL FIX)
# -----------------------------------------------------------------
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2-instance-profile-${var.ecr_repo_name}"
  role = aws_iam_role.ec2_ecr_role.name
}

# -----------------------------------------------------------------
# 3. EC2 Instance (Docker Host)
# -----------------------------------------------------------------
resource "aws_instance" "web_app_host" {
  ami             = var.ami_id
  instance_type   = var.instance_type
  key_name        = var.key_pair_name
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  
  # FIX: Attach the IAM Instance Profile to allow ECR authentication
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name

  # User data to install Docker, AWS CLI, and fix the PATH for ec2-user
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

              # CRITICAL: Add paths to .bashrc to ensure they load for ec2-user/Jenkins
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