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
# 0. Network Data Sources
# -----------------------------------------------------------------

# Look up the default VPC by ID
data "aws_vpc" "selected" {
  default = true
}

# Look up the specific subnet where the EC2 host is running.
data "aws_subnet" "selected" {
  vpc_id = data.aws_vpc.selected.id
  
  filter {
    # Filters for subnets where public IPs are assigned on launch (Public Subnet)
    name   = "map-public-ip-on-launch"
    values = ["true"]
  }
  
  filter {
    # Filters to the first Availability Zone to guarantee a single match
    values = ["${var.aws_region}a"] 
    name   = "availability-zone"
  }
}

# Look up the Route Table associated with that subnet (the MAIN route table)
data "aws_route_table" "selected" {
  vpc_id = data.aws_vpc.selected.id
  
  filter {
    name   = "association.main"
    values = ["true"]
  }
}

# -----------------------------------------------------------------
# 0a. CRITICAL FIX: Find Internet Gateway 
# -----------------------------------------------------------------
data "aws_internet_gateway" "selected" {
  filter {
    name   = "attachment.vpc-id"
    values = [data.aws_vpc.selected.id]
  }
}

# -----------------------------------------------------------------
# 0b. CRITICAL FIX: Ensure correct public route to Internet Gateway 
# This explicitly creates the correct route to fix the connection timeout.
# -----------------------------------------------------------------
resource "aws_route" "public_internet_route" {
  route_table_id         = data.aws_route_table.selected.id # Use the ID of the main route table
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = data.aws_internet_gateway.selected.id # Explicitly target the IGW ID
}


# -----------------------------------------------------------------
# 1. ECR (Elastic Container Registry) Repository
# -----------------------------------------------------------------
resource "aws_ecr_repository" "app_repo" {
  name                 = var.ecr_repo_name
  image_tag_mutability = "MUTABLE"
  force_delete         = true 

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
  vpc_id      = data.aws_vpc.selected.id 

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
# 3. IAM Role for ECR Access
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
# 4. IAM Instance Profile
# -----------------------------------------------------------------
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2-instance-profile-${var.ecr_repo_name}"
  role = aws_iam_role.ec2_ecr_role.name
}

# -----------------------------------------------------------------
# 5. VPC ENDPOINTS FOR ECR ACCESS (Network Access Fix)
# -----------------------------------------------------------------

# Security Group for the VPC Endpoints
resource "aws_security_group" "vpc_endpoint_sg" {
  name        = "vpc-endpoint-sg"
  description = "Allow inbound traffic from the main security group"
  vpc_id      = data.aws_vpc.selected.id 

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    security_groups = [aws_security_group.web_sg.id] 
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ECR API Endpoint (Interface)
resource "aws_vpc_endpoint" "ecr_api_endpoint" {
  vpc_id              = data.aws_vpc.selected.id
  service_name        = "com.amazonaws.${var.aws_region}.ecr.api"
  vpc_endpoint_type   = "Interface"
  security_group_ids  = [aws_security_group.vpc_endpoint_sg.id]
  subnet_ids          = [data.aws_subnet.selected.id]
  private_dns_enabled = true
}

# ECR DKR Endpoint (Interface)
resource "aws_vpc_endpoint" "ecr_dkr_endpoint" {
  vpc_id              = data.aws_vpc.selected.id
  service_name        = "com.amazonaws.${var.aws_region}.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  security_group_ids  = [aws_security_group.vpc_endpoint_sg.id]
  subnet_ids          = [data.aws_subnet.selected.id]
  private_dns_enabled = true
}

# S3 Gateway Endpoint
resource "aws_vpc_endpoint" "s3_endpoint" {
  vpc_id            = data.aws_vpc.selected.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  # Use the dynamically selected main route table
  route_table_ids = [data.aws_route_table.selected.id] 
}


# -----------------------------------------------------------------
# 6. EC2 Instance (Docker Host)
# -----------------------------------------------------------------
resource "aws_instance" "web_app_host" {
  ami                   = var.ami_id
  instance_type         = var.instance_type
  key_name              = var.key_pair_name
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  
  # Attach the IAM Instance Profile
  iam_instance_profile  = aws_iam_instance_profile.ec2_profile.name
  # Reference the dynamically selected Subnet ID 
  subnet_id             = data.aws_subnet.selected.id
  # 🟢 Added: Ensures a public IP is explicitly assigned
  associate_public_ip_address = true 


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
              
              # 🛑 FINAL FIX: Configure OS Firewall (Firewalld and iptables) to allow HTTP 🛑
              
              # Attempt to configure Firewalld (Standard for modern Amazon Linux/CentOS)
              if command -v firewall-cmd &> /dev/null
              then
                  echo "Configuring Firewalld for port 80..."
                  # Install firewalld if not present
                  sudo yum install -y firewalld
                  sudo systemctl start firewalld
                  sudo systemctl enable firewalld
                  sudo firewall-cmd --zone=public --add-port=80/tcp --permanent
                  sudo firewall-cmd --reload
              else
                  echo "Firewalld not found. Attempting iptables configuration..."
              fi
              
              # Ensure iptables allows Docker container traffic (for older AMIs/general compatibility)
              # This rule allows incoming traffic on port 80 (where Nginx is exposed)
              sudo iptables -I INPUT 1 -p tcp --dport 80 -j ACCEPT
              # Save the iptables rule so it persists across reboots
              sudo service iptables save || true
              
              echo "Setup complete. Docker and AWS CLI installed."
              EOF

  tags = {
    Name = "Jenkins-Web-App-Host"
  }
}

# 💡 CRITICAL FIX: Export the Public DNS Name for Jenkins to read dynamically
output "web_app_public_dns" {
  description = "The public DNS name of the Jenkins-Web-App-Host EC2 instance."
  value = aws_instance.web_app_host.public_dns
}