output "service_arn" {
  description = "ARN of the ECS service, for IAM policy scoping"
  value       = aws_ecs_service.this.arn
}