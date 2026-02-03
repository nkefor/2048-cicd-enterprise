# ============================================================
# Default Variable Values
# ============================================================
# These values configure a production-like deployment.
# Create environment-specific files for overrides:
#   terraform apply -var-file="environments/dev.tfvars"
# ============================================================

project_name = "game-2048"
environment  = "prod"
aws_region   = "us-east-1"

# VPC
vpc_cidr             = "10.0.0.0/16"
public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs = ["10.0.3.0/24", "10.0.4.0/24"]
single_nat_gateway   = true
enable_vpc_endpoints = true

# ECS
container_port            = 80
task_cpu                  = 256
task_memory               = 512
desired_count             = 2
min_capacity              = 1
max_capacity              = 10
enable_container_insights = true

# ALB
health_check_path     = "/"
health_check_interval = 15
health_check_timeout  = 5
healthy_threshold     = 2
unhealthy_threshold   = 3
enable_https          = false
certificate_arn       = ""

# ECR
ecr_image_retention_count = 20
ecr_scan_on_push          = true

# GitHub (for OIDC authentication)
github_owner = "nkefor"
github_repo  = "2048-cicd-enterprise"

# Monitoring
log_retention_days       = 30
alarm_email              = ""
cpu_alarm_threshold      = 80
memory_alarm_threshold   = 90
