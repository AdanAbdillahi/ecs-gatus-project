variable "aws_region" {
  type    = string
  default = "eu-west-2"
}

variable "role_name" {
  type    = string
  default = "gatus-ecs-github-actions"
}

# Owner/repo IDs are in the sub claim because the repo was renamed
variable "allowed_subjects" {
  type    = list(string)
  default = ["repo:AdanAbdillahi@99089028/ecs-gatus-project@1350685556:ref:refs/heads/main"]
}

variable "ecr_repository_name" {
  type    = string
  default = "gatus-ecs-ecr"
}

variable "ecs_cluster_name" {
  type    = string
  default = "gatus-ecs-cluster"
}

variable "ecs_service_name" {
  type    = string
  default = "gatus-ecs-service"
}

variable "terraform_ci_role_name" {
  type    = string
  default = "gatus-ecs-terraform-ci"
}

variable "terraform_ci_subjects" {
  type = list(string)
  default = [
    "repo:AdanAbdillahi@99089028/ecs-gatus-project@1350685556:ref:refs/heads/main",
    "repo:AdanAbdillahi@99089028/ecs-gatus-project@1350685556:pull_request",
  ]
}

variable "tf_state_bucket" {
  type    = string
  default = "ecs-gatus-tfstate-533267395439"
}

variable "tf_state_key" {
  type    = string
  default = "networking/terraform.tfstate"
}

# Must match local.name_prefix in the main terraform/ stack
variable "name_prefix" {
  type    = string
  default = "gatus-ecs"
}

variable "route53_zone_id" {
  type    = string
  default = "Z02906521H4NP7OMCMW5"
}
