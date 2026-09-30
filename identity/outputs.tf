output "github_actions_role_arn" {
  description = "Paste into .github/workflows/build-and-push.yml's role-to-assume"
  value       = aws_iam_role.github_actions.arn
}

output "terraform_ci_role_arn" {
  description = "Paste into .github/workflows/terraform-infra.yml's role-to-assume"
  value       = aws_iam_role.terraform_ci.arn
}

output "oidc_provider_arn" {
  description = "The single GitHub OIDC trust anchor both roles above hang off"
  value       = aws_iam_openid_connect_provider.github.arn
}
