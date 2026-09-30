output "ecr_repository_url" {
  description = "URL of the ECR repository for pushing images"
  value       = module.ecr.repository_url
}

output "alb_dns_name" {
  description = "DNS name of the ALB"
  value       = module.alb.dns_name
}

output "github_actions_role_arn" {
  description = "ARN of the IAM role GitHub Actions assumes via OIDC - managed in ../identity, not by this stack. Kept here as a convenience so it's still visible via `terraform output`."
  value       = "arn:aws:iam::533267395439:role/gatus-ecs-github-actions"
}

output "terraform_ci_role_arn" {
  description = "ARN of the IAM role terraform-infra.yml assumes via OIDC - managed in ../identity, not by this stack."
  value       = "arn:aws:iam::533267395439:role/gatus-ecs-terraform-ci"
}