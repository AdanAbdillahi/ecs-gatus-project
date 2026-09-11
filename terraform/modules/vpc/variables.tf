variable "name_prefix" {
  description = "Prefix applied to all resource names and tags"
  type        = string
}

variable "vpc_cidr" {
  description = "cidr range of vpc"
  type        = string
  default     = "10.0.0.0/24"
}

variable "public_subnets" {
  description = "Public subnets, keyed by availability zone -> CIDR block."
  type        = map(string)
}

variable "private_subnets" {
  description = "Private subnets, keyed by availability zone -> CIDR block."
  type        = map(string)
}

variable "nat_gateway_az" {
  description = "Availability zone of the public subnet the NAT Gateway sits in"
  type        = string
}

