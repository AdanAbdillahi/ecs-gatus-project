variable "name_prefix" {
    description = "name of project"
    type = string

}

variable "app_port" {
    description = "port of gatus applicaiton"
    type = number
}

variable "image_tag" {
    description = "commit SHA tag of the image being deployed"
    type = string
    default = "latest"
}

variable "repository_url" {
    description = "url of ecr repository to be used in ecs tasks"
    type = string
}

variable "region" {
  description = "AWS region"
  type        = string
}
variable "private_subnets" {
  description = "Map of private subnet IDs keyed by AZ"
  type        = map(string)
}

variable "ecs_security_group_id" {
  description = "ID of the ECS tasks security group"
  type        = string
}

variable "target_group_arn" {
  description = "ARN of the ALB target group to register tasks with"
  type        = string
}