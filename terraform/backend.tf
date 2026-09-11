terraform {

  backend "s3" {
    bucket       = "ecs-gatus-tfstate-533267395439"
    key          = "networking/terraform.tfstate"
    region       = "eu-west-2"
    encrypt      = true
    use_lockfile = true
  }
}
