# ============================================================
# Input Variables
# ============================================================
# All configurable parameters for the infrastructure.
# Override defaults via terraform.tfvars or -var flags.
# ============================================================

# ------------------------------
# General
# ------------------------------
variable "project_name" {
  description = "Project name used as prefix for all resources"
  type        = string
  default     = "game-2048"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "prod"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}

# ------------------------------
# VPC & Networking
# ------------------------------
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets (one per AZ)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets (one per AZ)"
  type        = list(string)
  default     = ["10.0.3.0/24", "10.0.4.0/24"]
}

variable "enable_vpc_endpoints" {
  description = "Create VPC endpoints for ECR, CloudWatch, and S3"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use a single NAT gateway instead of one per AZ (cost saving for non-prod)"
  type        = bool
  default     = true
}

# ------------------------------
# ECS Configuration
# ------------------------------
variable "container_port" {
  description = "Port the container listens on"
  type        = number
  default     = 80
}

variable "task_cpu" {
  description = "CPU units for the ECS task (256 = 0.25 vCPU)"
  type        = number
  default     = 256
}

variable "task_memory" {
  description = "Memory in MB for the ECS task"
  type        = number
  default     = 512
}

variable "desired_count" {
  description = "Desired number of tasks per service"
  type        = number
  default     = 2
}

variable "min_capacity" {
  description = "Minimum number of tasks (auto-scaling)"
  type        = number
  default     = 1
}

variable "max_capacity" {
  description = "Maximum number of tasks (auto-scaling)"
  type        = number
  default     = 10
}

variable "container_image" {
  description = "Default container image (overridden by CI/CD pipeline)"
  type        = string
  default     = "nginx:1.27-alpine"
}

variable "health_check_path" {
  description = "Health check path for ALB target groups"
  type        = string
  default     = "/"
}

variable "enable_container_insights" {
  description = "Enable CloudWatch Container Insights on the ECS cluster"
  type        = bool
  default     = true
}

# ------------------------------
# ALB Configuration
# ------------------------------
variable "enable_https" {
  description = "Enable HTTPS listener (requires certificate_arn)"
  type        = bool
  default     = false
}

variable "certificate_arn" {
  description = "ACM certificate ARN for HTTPS listener"
  type        = string
  default     = ""
}

variable "health_check_interval" {
  description = "ALB health check interval in seconds"
  type        = number
  default     = 15
}

variable "health_check_timeout" {
  description = "ALB health check timeout in seconds"
  type        = number
  default     = 5
}

variable "healthy_threshold" {
  description = "Number of consecutive successful checks to mark healthy"
  type        = number
  default     = 2
}

variable "unhealthy_threshold" {
  description = "Number of consecutive failed checks to mark unhealthy"
  type        = number
  default     = 3
}

# ------------------------------
# ECR Configuration
# ------------------------------
variable "ecr_image_retention_count" {
  description = "Number of images to retain in ECR (older images expire)"
  type        = number
  default     = 20
}

variable "ecr_scan_on_push" {
  description = "Enable vulnerability scanning on image push"
  type        = bool
  default     = true
}

# ------------------------------
# GitHub OIDC
# ------------------------------
variable "github_owner" {
  description = "GitHub repository owner (organization or username)"
  type        = string
  default     = "nkefor"
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
  default     = "2048-cicd-enterprise"
}

# ------------------------------
# CloudWatch & Monitoring
# ------------------------------
variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 30
}

variable "alarm_email" {
  description = "Email address for CloudWatch alarm notifications (empty to skip)"
  type        = string
  default     = ""
}

variable "cpu_alarm_threshold" {
  description = "CPU utilization percentage to trigger alarm"
  type        = number
  default     = 80
}

variable "memory_alarm_threshold" {
  description = "Memory utilization percentage to trigger alarm"
  type        = number
  default     = 90
}
