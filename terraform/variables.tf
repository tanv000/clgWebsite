variable "region" {
  description = "AWS region"
  default     = "ap-south-1"
}

variable "instance_type" {
  description = "EC2 instance type"
  default     = "t3.micro"
}

variable "key_name" {
  description = "Name of existing EC2 key pair"
  default     = "jenkins-pipeline-key"
}

variable "security_group_name" {
  description = "Security group name"
  default     = "jenkins-ec2-sg"
}
