# outputs.tf

output "ecr_repository_url" {
  description = "The URL for the ECR repository."
  value       = aws_ecr_repository.app_repo.repository_url
}

output "web_app_public_ip" {
  description = "The public IP address of the EC2 instance host."
  # This targets the public IP of the EC2 resource named "web_app_host"
  value       = aws_instance.web_app_host.public_ip
}