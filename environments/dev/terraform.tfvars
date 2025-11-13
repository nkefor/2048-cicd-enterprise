# Development Environment Configuration
# Purpose: Development and testing environment with minimal resources

environment         = "dev"
project_name        = "2048-cicd-dev"
aws_region          = "us-east-1"

# Container Configuration (Minimal for dev)
container_port      = 80
desired_count       = 1        # Single instance for dev
cpu                 = 256      # 0.25 vCPU (minimal)
memory              = 512      # 0.5 GB (minimal)

# Auto-scaling Configuration (Limited for dev)
min_capacity        = 1
max_capacity        = 3
cpu_threshold       = 80
memory_threshold    = 85

# Health Check Configuration
health_check_path              = "/health"
health_check_interval          = 30
health_check_timeout           = 5
health_check_healthy_threshold = 2
health_check_unhealthy_threshold = 3

# Networking (Single AZ for cost savings)
vpc_cidr            = "10.0.0.0/16"
availability_zones  = ["us-east-1a", "us-east-1b"]  # 2 AZs minimum for ALB

# Logging & Monitoring (Reduced retention)
log_retention_days  = 7        # 1 week retention for dev
enable_detailed_monitoring = false

# Cost Optimization (Dev environment)
enable_auto_shutdown = true    # Auto-shutdown after hours
shutdown_schedule    = "cron(0 22 * * ? *)"  # 10 PM UTC
startup_schedule     = "cron(0 8 * * MON-FRI *)"  # 8 AM UTC weekdays

# Tags
tags = {
  Environment = "dev"
  ManagedBy   = "Terraform"
  Project     = "2048-cicd-enterprise"
  CostCenter  = "development"
  AutoShutdown = "true"
}
