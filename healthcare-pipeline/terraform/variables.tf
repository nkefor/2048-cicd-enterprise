# Secure Healthcare Data Pipeline - Variables
# Configuration variables for the infrastructure

# Project Configuration
variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "healthcare-pii-pipeline"
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

variable "owner_email" {
  description = "Email of the project owner"
  type        = string
}

# AWS Region Configuration
variable "primary_region" {
  description = "Primary AWS region"
  type        = string
  default     = "us-east-1"
}

variable "dr_region" {
  description = "Disaster recovery AWS region"
  type        = string
  default     = "us-west-2"
}

# VPC Configuration
variable "vpc_cidr" {
  description = "CIDR block for VPC in primary region"
  type        = string
  default     = "10.0.0.0/16"
}

variable "vpc_cidr_dr" {
  description = "CIDR block for VPC in DR region"
  type        = string
  default     = "10.1.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones for primary region"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "availability_zones_dr" {
  description = "Availability zones for DR region"
  type        = list(string)
  default     = ["us-west-2a", "us-west-2b", "us-west-2c"]
}

# S3 Configuration
variable "s3_lifecycle_rules" {
  description = "S3 lifecycle rules for data management"
  type = list(object({
    id                            = string
    enabled                       = bool
    transition_days               = number
    transition_storage_class      = string
    expiration_days               = number
  }))
  default = [
    {
      id                       = "archive-old-data"
      enabled                  = true
      transition_days          = 90
      transition_storage_class = "GLACIER"
      expiration_days          = 2555  # 7 years for HIPAA compliance
    }
  ]
}

# Lambda Configuration
variable "lambda_runtime" {
  description = "Lambda runtime environment"
  type        = string
  default     = "python3.11"
}

variable "lambda_timeout" {
  description = "Lambda function timeout in seconds"
  type        = number
  default     = 900
}

variable "lambda_memory" {
  description = "Lambda function memory in MB"
  type        = number
  default     = 2048
}

# FHIR API Configuration
variable "fhir_api_image_uri" {
  description = "Docker image URI for FHIR API"
  type        = string
  default     = ""
}

variable "fhir_api_cpu" {
  description = "CPU units for FHIR API (256, 512, 1024, 2048, 4096)"
  type        = number
  default     = 1024
}

variable "fhir_api_memory" {
  description = "Memory for FHIR API in MB"
  type        = number
  default     = 2048
}

# Databricks Configuration
variable "databricks_host" {
  description = "Databricks workspace host"
  type        = string
  default     = ""
  sensitive   = true
}

variable "databricks_token" {
  description = "Databricks API token"
  type        = string
  default     = ""
  sensitive   = true
}

variable "databricks_account_id" {
  description = "Databricks account ID"
  type        = string
  default     = ""
}

# Monitoring Configuration
variable "enable_datadog" {
  description = "Enable Datadog integration"
  type        = bool
  default     = true
}

variable "datadog_api_key" {
  description = "Datadog API key"
  type        = string
  default     = ""
  sensitive   = true
}

variable "splunk_hec_endpoint" {
  description = "Splunk HTTP Event Collector endpoint"
  type        = string
  default     = ""
}

variable "splunk_hec_token" {
  description = "Splunk HEC token"
  type        = string
  default     = ""
  sensitive   = true
}

# Alert Configuration
variable "alert_email_addresses" {
  description = "Email addresses for alert notifications"
  type        = list(string)
  default     = []
}

# SageMaker Configuration
variable "sagemaker_instance_type" {
  description = "SageMaker instance type for model training"
  type        = string
  default     = "ml.m5.xlarge"
}

variable "sagemaker_endpoint_instance_type" {
  description = "SageMaker instance type for endpoint"
  type        = string
  default     = "ml.t3.medium"
}

# Compliance Configuration
variable "enable_hipaa_compliance" {
  description = "Enable HIPAA compliance features"
  type        = bool
  default     = true
}

variable "data_retention_days" {
  description = "Data retention period in days"
  type        = number
  default     = 2555  # 7 years for HIPAA
}

variable "audit_log_retention_days" {
  description = "Audit log retention period in days"
  type        = number
  default     = 2555
}

# Auto Scaling Configuration
variable "lambda_reserved_concurrency" {
  description = "Reserved concurrent executions for Lambda"
  type        = number
  default     = 100
}

variable "ecs_min_tasks" {
  description = "Minimum number of ECS tasks"
  type        = number
  default     = 2
}

variable "ecs_max_tasks" {
  description = "Maximum number of ECS tasks"
  type        = number
  default     = 10
}

variable "ecs_cpu_target" {
  description = "Target CPU utilization percentage for auto-scaling"
  type        = number
  default     = 70
}

variable "ecs_memory_target" {
  description = "Target memory utilization percentage for auto-scaling"
  type        = number
  default     = 80
}

# Security Configuration
variable "enable_encryption_at_rest" {
  description = "Enable encryption at rest for all data stores"
  type        = bool
  default     = true
}

variable "enable_encryption_in_transit" {
  description = "Enable encryption in transit"
  type        = bool
  default     = true
}

variable "enable_mfa_delete" {
  description = "Enable MFA delete for S3 buckets"
  type        = bool
  default     = true
}

variable "allowed_ip_ranges" {
  description = "Allowed IP ranges for API access"
  type        = list(string)
  default     = []
}

# Backup Configuration
variable "enable_automated_backups" {
  description = "Enable automated backups"
  type        = bool
  default     = true
}

variable "backup_retention_days" {
  description = "Backup retention period in days"
  type        = number
  default     = 35
}

# Cost Optimization
variable "enable_spot_instances" {
  description = "Enable Spot instances for cost optimization"
  type        = bool
  default     = false
}

variable "enable_s3_intelligent_tiering" {
  description = "Enable S3 Intelligent-Tiering"
  type        = bool
  default     = true
}

# Tags
variable "additional_tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
