terraform {
  # Own state/key on purpose - keeps terraform_ci's runs from ever touching
  # these resources. Applied by hand only, never from CI.
  backend "s3" {
    bucket       = "ecs-gatus-tfstate-533267395439"
    key          = "identity/terraform.tfstate"
    region       = "eu-west-2"
    encrypt      = true
    use_lockfile = true
  }
}
