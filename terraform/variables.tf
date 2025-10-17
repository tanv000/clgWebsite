# -----------------------------------------------------------------
# AWS Region
# -----------------------------------------------------------------
variable "aws_region" {
  description = "The AWS region where resources will be created"
  type        = string
  default     = "ap-south-1" # Updated to ap-south-1
}

# -----------------------------------------------------------------
# EC2 Configuration
# -----------------------------------------------------------------
variable "ami_id" {
  description = "AMI ID for Amazon Linux 2023 in ap-south-1"
  type        = string
  # AMI ID for Amazon Linux 2023 in ap-south-1 (Mumbai)
  default     = "ami-06fa3f12191aa3337" 
}

variable "instance_type" {
  description = "The EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "key_pair_name" {
  description = "The name of your existing EC2 Key Pair for SSH access"
  type        = string
  # CRITICAL: Replace 'your-key-pair-name' with the actual name of your key pair
  default     = "jenkins-pipeline-key" 
}

# -----------------------------------------------------------------
# ECR Repository Name and App Name
# -----------------------------------------------------------------
variable "ecr_repo_name" {
  description = "Name for the ECR repository"
  type        = string
  default     = "abc-college-web-app"
}

variable "app_name" {
  description = "Name to tag the EC2 instance"
  type        = string
  default     = "ABC College Web App Server"
}
