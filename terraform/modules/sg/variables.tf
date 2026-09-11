variable "name_prefix" {
  description = "name of application/project"
  type        = string
}

variable "vpc_id" {
  description = "ID of VPC for the SG"
  type        = string
}

variable "app_port" {

  description = "Port for Gatus application to listen on"
  type        = number
}