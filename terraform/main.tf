# Networking stack.
locals {
  name_prefix = "gatus-ecs"
}

module "vpc" {
  source = "./modules/vpc"

  name_prefix    = local.name_prefix
  nat_gateway_az = "eu-west-2a"

  public_subnets = {
    "eu-west-2a" = "10.0.0.0/26"
    "eu-west-2b" = "10.0.0.64/26"
  }

  private_subnets = {
    "eu-west-2a" = "10.0.0.128/26"
    "eu-west-2b" = "10.0.0.192/26"
  }
}


module "sg" {
  source = "./modules/sg"

  name_prefix = local.name_prefix
  vpc_id      = module.vpc.vpc_id
  app_port    = var.app_port
}
