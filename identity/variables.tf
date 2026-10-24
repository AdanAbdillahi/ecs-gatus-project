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
