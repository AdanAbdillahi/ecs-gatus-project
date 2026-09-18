output "ecr_repository_url" {
  description = "URL of the ECR repository for pushing images"
  value       = module.ecr.repository_url
}

output "alb_dns_name" {
  description = "DNS name of the ALB"
  value       = module.alb.dns_name
}