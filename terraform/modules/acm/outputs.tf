output "certificate_arn" {
  value       = aws_acm_certificate.cert.arn
  description = "ARN of certificate"
  depends_on  = [aws_acm_certificate_validation.this]
}