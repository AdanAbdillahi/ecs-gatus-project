variable "domain_name" {
  description = "Root domain name"
  type        = string
}

variable "alb_dns_name" {
  description = "DNS name of the ALB to alias to"
  type        = string
}

variable "alb_zone_id" {
  description = "Hosted zone ID of the ALB"
  type        = string
}