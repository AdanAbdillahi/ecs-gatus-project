resource "aws_security_group" "alb_sg" {
  name        = "alb_sg"
  description = "Internet facing ALB SG, allows inbound HTTPS from anywhere"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.name_prefix}-alb-sg"
  }
}
resource "aws_vpc_security_group_ingress_rule" "alb_http_from_internet" {
  description       = "HTTP from internet (redirected to HTTPS)"
  security_group_id = aws_security_group.alb_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}


resource "aws_vpc_security_group_ingress_rule" "alb_from_internet" {
  description       = "HTTPS from internet"
  security_group_id = aws_security_group.alb_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  ip_protocol       = "tcp"
  to_port           = 443
}

resource "aws_vpc_security_group_egress_rule" "alb_to_ecs" {
  description                  = "App port to ECS tasks"
  security_group_id            = aws_security_group.alb_sg.id
  referenced_security_group_id = aws_security_group.ecs_sg.id
  from_port                    = var.app_port
  ip_protocol                  = "tcp"
  to_port                      = var.app_port
}

resource "aws_security_group" "ecs_sg" {
  name        = "ecs_sg"
  description = " Gatus ECS task SG - allows traffic from only ALB"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.name_prefix}-ecs-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "ecs_from_alb" {
  description                  = "App port from ALB"
  security_group_id            = aws_security_group.ecs_sg.id
  referenced_security_group_id = aws_security_group.alb_sg.id
  from_port                    = var.app_port
  ip_protocol                  = "tcp"
  to_port                      = var.app_port
}

# ECR/CloudWatch via NAT, plus the HTTPS endpoints in config.yaml
resource "aws_vpc_security_group_egress_rule" "ecs_https" {
  description       = "HTTPS out"
  security_group_id = aws_security_group.ecs_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  ip_protocol       = "tcp"
  to_port           = 443
}