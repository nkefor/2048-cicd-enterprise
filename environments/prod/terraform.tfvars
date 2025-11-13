# Production Environment Configuration
# Purpose: Production environment with high availability and performance

environment         = "prod"
project_name        = "2048-cicd-prod"
aws_region          = "us-east-1"

# Container Configuration (Production-ready)
container_port      = 80
desired_count       = 3        # 3 instances minimum for HA
cpu                 = 512      # 0.5 vCPU
memory              = 1024     # 1 GB

# Auto-scaling Configuration (Production scale)
min_capacity        = 3
max_capacity        = 20
cpu_threshold       = 70
memory_threshold    = 80

# Health Check Configuration (Strict)
health_check_path              = "/health"
health_check_interval          = 30
health_check_timeout           = 5
health_check_healthy_threshold = 3  # Stricter for prod
health_check_unhealthy_threshold = 2  # Faster failure detection

# Networking (Multi-AZ for maximum availability)
vpc_cidr            = "10.2.0.0/16"
availability_zones  = ["us-east-1a", "us-east-1b", "us-east-1c"]

# Logging & Monitoring (Extended retention for compliance)
log_retention_days  = 90       # 90 days retention for prod
enable_detailed_monitoring = true

# Backup Configuration (Production only)
enable_automated_backups = true
backup_retention_days    = 30
backup_window           = "03:00-04:00"  # 3-4 AM UTC
maintenance_window      = "sun:04:00-sun:05:00"  # Sunday 4-5 AM UTC

# Cost Optimization (Production - no auto-shutdown)
enable_auto_shutdown = false   # Always on for production
enable_reserved_capacity = true  # Consider reserved instances for cost savings

# Security (Production hardening)
enable_waf                 = true   # Web Application Firewall
enable_shield_advanced     = false  # Optional: DDoS protection ($3000/month)
enable_enhanced_monitoring = true
enable_encryption_at_rest  = true
enable_encryption_in_transit = true

# Disaster Recovery
enable_multi_region_backup = true
dr_region                  = "us-west-2"
enable_cross_region_replication = true

# Tags
tags = {
  Environment = "production"
  ManagedBy   = "Terraform"
  Project     = "2048-cicd-enterprise"
  CostCenter  = "production"
  Criticality = "high"
  Compliance  = "required"
  BackupPolicy = "daily"
  AutoShutdown = "false"
}
