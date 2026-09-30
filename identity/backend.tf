terraform {
  # Deliberately its own state, in its own key, in the same bucket the main
  # stack uses. This is what actually enforces the separation: terraform_ci
  # (which only ever runs against the "networking/*" key) has no state file
  # in which the OIDC provider or either role even exists, so it has nothing
  # to `terraform apply` against even if its IAM policy were looser than it
  # is. Applied by hand from adan-cli, never from CI - see README.
  backend "s3" {
    bucket       = "ecs-gatus-tfstate-533267395439"
    key          = "identity/terraform.tfstate"
    region       = "eu-west-2"
    encrypt      = true
    use_lockfile = true
  }
}
