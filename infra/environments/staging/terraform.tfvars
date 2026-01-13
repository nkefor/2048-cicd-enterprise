# Staging Environment Configuration

environment = "staging"
aws_region  = "us-east-1"

# VPC Configuration
vpc_cidr           = "10.1.0.0/16"
availability_zones = ["us-east-1a", "us-east-1b"]
enable_nat_gateway = true
single_nat_gateway = true # Cost optimization: single NAT gateway

# ECR Configuration
ecr_image_tag_mutability = "MUTABLE"
ecr_scan_on_push         = true

# ALB Configuration
alb_enable_deletion_protection = false
alb_enable_http2              = true
alb_enable_access_logs        = false
enable_https                  = false

# ECS Configuration
ecs_task_cpu    = 256
ecs_task_memory = 512
container_port  = 80

# Service Scaling
ecs_desired_count = 2
ecs_min_capacity  = 1
ecs_max_capacity  = 4

# Auto-scaling Thresholds
ecs_cpu_target_value    = 70
ecs_memory_target_value = 80

# Deployment Configuration
deployment_controller_type    = "CODE_DEPLOY"
enable_blue_green_deployment = true
health_check_grace_period    = 60

# Logging
log_retention_days = 14
