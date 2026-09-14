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

module "alb" {
  source = "./modules/alb"

  name_prefix           = local.name_prefix
  public_subnets        = module.vpc.public_subnet_ids
  alb_security_group_id = module.sg.alb_sg_id # assuming sg module outputs this
  vpc_id                = module.vpc.vpc_id
  certificate_arn       = module.acm.certificate_arn
  app_port              = var.app_port
}

module "acm" {
  source      = "./modules/acm"
  name_prefix = local.name_prefix
  domain_name = var.domain_name
}

module "r53" {
  source = "./modules/r53"

  domain_name  = var.domain_name
  alb_dns_name = module.alb.dns_name
  alb_zone_id  = module.alb.zone_id
}