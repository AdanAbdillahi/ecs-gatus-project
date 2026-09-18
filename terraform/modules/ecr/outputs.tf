output "repository_url" {
  description = "URL of the ECR repo to be used in task definitions"
  value       = aws_ecr_repository.this.repository_url

}