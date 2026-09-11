output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.this.id
}

output "public_subnet_ids" {
  description = "Map of public subnet IDs keyed by AZ"
  value       = { for k, v in aws_subnet.public : k => v.id }
}

output "private_subnet_ids" {
  description = "Map of private subnet IDs keyed by AZ"
  value       = { for k, v in aws_subnet.private : k => v.id }
}