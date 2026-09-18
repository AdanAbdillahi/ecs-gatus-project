output "alb_sg_id" {
  description = "SG id for ALB"
  value       = aws_security_group.alb_sg.id
}

output "ecs_sg_id" {
  description = "SG id for ECS"
  value       = aws_security_group.ecs_sg.id
}

