# Staging Environment Configuration
# Purpose: Pre-production testing and validation environment

environment         = "staging"
project_name        = "2048-cicd-staging"
aws_region          = "us-east-1"

# Container Configuration (Production-like but smaller)
container_port      = 80
desired_count       = 2        # 2 instances for staging
cpu                 = 512      # 0.5 vCPU
memory              = 1024     # 1 GB

# Auto-scaling Configuration (Production-like)
min_capacity        = 2
max_capacity        = 10
cpu_threshold       = 70
memory_threshold    = 80

# Health Check Configuration
health_check_path              = "/health"
health_check_interval          = 30
health_check_timeout           = 5
health_check_healthy_threshold = 2
health_check_unhealthy_threshold = 3

# Networking (Multi-AZ for HA testing)
vpc_cidr            = "10.1.0.0/16"
availability_zones  = ["us-east-1a", "us-east-1b", "us-east-1c"]

# Logging & Monitoring (Moderate retention)
log_retention_days  = 30       # 30 days retention for staging
enable_detailed_monitoring = true

# Cost Optimization (Staging environment)
enable_auto_shutdown = true    # Auto-shutdown weekends
shutdown_schedule    = "cron(0 22 * * FRI *)"  # Friday 10 PM UTC
startup_schedule     = "cron(0 8 * * MON *)"   # Monday 8 AM UTC

# Tags
tags = {
  Environment = "staging"
  ManagedBy   = "Terraform"
  Project     = "2048-cicd-enterprise"
  CostCenter  = "staging"
  AutoShutdown = "true"
  Purpose     = "pre-production-testing"
}
