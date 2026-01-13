# Production Environment Configuration

environment = "prod"
aws_region  = "us-east-1"

# VPC Configuration
vpc_cidr           = "10.0.0.0/16"
availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]
enable_nat_gateway = true
single_nat_gateway = false # Use NAT gateway per AZ for high availability

# ECR Configuration
ecr_image_tag_mutability = "IMMUTABLE"
ecr_scan_on_push         = true

# ALB Configuration
alb_enable_deletion_protection = true
alb_enable_http2              = true
alb_enable_access_logs        = true
# alb_access_logs_bucket       = "my-alb-logs-bucket-prod"
# ssl_certificate_arn          = "arn:aws:acm:us-east-1:123456789012:certificate/xxxxx"
enable_https                  = false # Set to true when SSL certificate is available

# ECS Configuration
ecs_task_cpu    = 512
ecs_task_memory = 1024
container_port  = 80

# Service Scaling
ecs_desired_count = 3
ecs_min_capacity  = 2
ecs_max_capacity  = 10

# Auto-scaling Thresholds
ecs_cpu_target_value    = 70
ecs_memory_target_value = 80

# Deployment Configuration
deployment_controller_type    = "CODE_DEPLOY"
enable_blue_green_deployment = true
health_check_grace_period    = 60

# Logging
log_retention_days = 30
