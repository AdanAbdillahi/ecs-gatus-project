variable "name_prefix" {
  description = "Prefix applied to all resource names and tags"
  type        = string
}

variable "public_subnets" {
  description = "Map of public subnet IDs keyed by AZ"
  type        = map(string)
}

variable "alb_security_group_id" {
  description = "ID of the security group to attach to the ALB"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC the ALB and target group belong to"
  type        = string
}

variable "app_port" {
  description = "Port value for Gatus App"
  type = number
}


variable "certificate_arn" {
description = "ARN of the certificate"
type = string 
}