output "dns_name" {
  description = "DNS name of the ALB"
  value       = aws_lb.this.dns_name
}

output "zone_id" {
  description = "Hosted zone ID of the ALB (for Route 53 alias records)"
  value       = aws_lb.this.zone_id
}
