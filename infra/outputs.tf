# ============================================================
# Terraform Outputs
# ============================================================
# These values are needed by the CI/CD pipeline and should be
# configured as GitHub repository secrets after terraform apply.
# ============================================================

# ------------------------------
# ALB
# ------------------------------
output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.main.dns_name
}

output "alb_url" {
  description = "Full URL to access the application"
  value       = "http://${aws_lb.main.dns_name}"
}

output "alb_listener_arn" {
  description = "ARN of the HTTP listener (set as ALB_LISTENER_ARN GitHub secret)"
  value       = aws_lb_listener.http.arn
}

# ------------------------------
# Target Groups
# ------------------------------
output "target_group_blue_arn" {
  description = "ARN of the blue target group (set as TG_BLUE_ARN GitHub secret)"
  value       = aws_lb_target_group.blue.arn
}

output "target_group_green_arn" {
  description = "ARN of the green target group (set as TG_GREEN_ARN GitHub secret)"
  value       = aws_lb_target_group.green.arn
}

# ------------------------------
# ECR
# ------------------------------
output "ecr_repository_url" {
  description = "ECR repository URL (set as ECR_REPO GitHub secret)"
  value       = aws_ecr_repository.app.repository_url
}

output "ecr_repository_arn" {
  description = "ARN of the ECR repository"
  value       = aws_ecr_repository.app.arn
}

# ------------------------------
# ECS
# ------------------------------
output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.main.name
}

output "ecs_cluster_arn" {
  description = "ARN of the ECS cluster"
  value       = aws_ecs_cluster.main.arn
}

output "ecs_service_blue_name" {
  description = "Name of the blue ECS service"
  value       = aws_ecs_service.blue.name
}

output "ecs_service_green_name" {
  description = "Name of the green ECS service"
  value       = aws_ecs_service.green.name
}

# ------------------------------
# IAM
# ------------------------------
output "github_actions_role_arn" {
  description = "ARN of the GitHub Actions IAM role (set as AWS_ROLE_ARN GitHub secret)"
  value       = aws_iam_role.github_actions.arn
}

# ------------------------------
# VPC
# ------------------------------
output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = aws_subnet.private[*].id
}

# ------------------------------
# Monitoring
# ------------------------------
output "cloudwatch_log_group" {
  description = "CloudWatch log group for ECS tasks"
  value       = aws_cloudwatch_log_group.ecs.name
}

output "sns_topic_arn" {
  description = "ARN of the SNS topic for deploy notifications"
  value       = aws_sns_topic.deploy_notifications.arn
}

output "cloudwatch_dashboard_url" {
  description = "URL to the CloudWatch dashboard"
  value       = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${local.name_prefix}-dashboard"
}

# ------------------------------
# Summary for GitHub Secrets
# ------------------------------
output "github_secrets_summary" {
  description = "Summary of values to configure as GitHub repository secrets"
  value = {
    AWS_REGION       = var.aws_region
    ECR_REPO         = aws_ecr_repository.app.repository_url
    AWS_ROLE_ARN     = aws_iam_role.github_actions.arn
    TG_BLUE_ARN      = aws_lb_target_group.blue.arn
    TG_GREEN_ARN     = aws_lb_target_group.green.arn
    ALB_LISTENER_ARN = aws_lb_listener.http.arn
  }
}
