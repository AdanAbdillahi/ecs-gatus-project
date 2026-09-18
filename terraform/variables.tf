variable "region" {
  description = "AWS region for all networking resources"
  type        = string
  default     = "eu-west-2"
}

variable "app_port" {
  description = "Port the Gatus application listens on"
  type        = number
  default     = 8080
}

variable "domain_name" {
  description = "Name of the domain"
  type        = string
  default     = "adanabdillahi.com"
}

variable "image_tag" {
  description = "commit SHA tag of the image being deployed"
  type        = string
}
