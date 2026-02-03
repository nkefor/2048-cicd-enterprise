# ============================================================
# Application Load Balancer, Target Groups, and Listeners
# ============================================================
# Two target groups support blue/green deployment.
# The CI/CD pipeline switches the listener's default action
# between target groups during deployment.
# ============================================================

# ------------------------------
# Application Load Balancer
# ------------------------------
resource "aws_lb" "main" {
  name               = "${local.name_prefix}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id

  enable_deletion_protection = var.environment == "prod"

  tags = {
    Name = "${local.name_prefix}-alb"
  }
}

# ------------------------------
# Target Group: Blue
# ------------------------------
resource "aws_lb_target_group" "blue" {
  name        = "${local.name_prefix}-tg-blue"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    enabled             = true
    path                = var.health_check_path
    port                = "traffic-port"
    protocol            = "HTTP"
    interval            = var.health_check_interval
    timeout             = var.health_check_timeout
    healthy_threshold   = var.healthy_threshold
    unhealthy_threshold = var.unhealthy_threshold
    matcher             = "200"
  }

  # Allow target deregistration to complete before destroying
  deregistration_delay = 30

  tags = {
    Name        = "${local.name_prefix}-tg-blue"
    Environment = "blue"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ------------------------------
# Target Group: Green
# ------------------------------
resource "aws_lb_target_group" "green" {
  name        = "${local.name_prefix}-tg-green"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    enabled             = true
    path                = var.health_check_path
    port                = "traffic-port"
    protocol            = "HTTP"
    interval            = var.health_check_interval
    timeout             = var.health_check_timeout
    healthy_threshold   = var.healthy_threshold
    unhealthy_threshold = var.unhealthy_threshold
    matcher             = "200"
  }

  deregistration_delay = 30

  tags = {
    Name        = "${local.name_prefix}-tg-green"
    Environment = "green"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ------------------------------
# HTTP Listener (port 80)
# ------------------------------
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  # Default: forward to blue target group.
  # The CI/CD pipeline modifies this during blue/green deployment.
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.blue.arn
  }

  # Terraform should not fight the CI/CD pipeline for control of the
  # default action target group. After initial creation, the pipeline
  # manages which target group is active.
  lifecycle {
    ignore_changes = [default_action]
  }

  tags = {
    Name = "${local.name_prefix}-listener-http"
  }
}

# ------------------------------
# HTTPS Listener (port 443) - optional
# ------------------------------
resource "aws_lb_listener" "https" {
  count = var.enable_https ? 1 : 0

  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.blue.arn
  }

  lifecycle {
    ignore_changes = [default_action]
  }

  tags = {
    Name = "${local.name_prefix}-listener-https"
  }
}

# HTTP to HTTPS redirect (when HTTPS is enabled)
resource "aws_lb_listener_rule" "http_redirect" {
  count = var.enable_https ? 1 : 0

  listener_arn = aws_lb_listener.http.arn
  priority     = 1

  action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }

  condition {
    path_pattern {
      values = ["/*"]
    }
  }
}
