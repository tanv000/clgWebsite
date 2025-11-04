output "ecr_repo_url" {
  value       = aws_ecr_repository.website.repository_url
  description = "ECR repository URL"
}

output "ec2_public_ip" {
  value       = aws_instance.web.public_ip
  description = "EC2 Public IP"
}

output "ec2_public_dns" {
  value       = aws_instance.web.public_dns
  description = "EC2 Public DNS"
}

output "ec2_instance_id" {
  value       = aws_instance.web.id
  description = "EC2 Instance ID"
}
