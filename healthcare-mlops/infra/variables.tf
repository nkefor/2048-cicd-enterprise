variable "project_name" {
  description = "Project name for healthcare MLOps platform"
  type        = string
  default     = "healthcare-mlops"
}

variable "resource_group_name" {
  description = "Name of the Azure resource group"
  type        = string
  default     = "healthcare-mlops-rg"
}

variable "location" {
  description = "Primary Azure region"
  type        = string
  default     = "eastus"
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
  default     = "prod"
}

variable "security_email" {
  description = "Email for security alerts"
  type        = string
  default     = "security@healthcare-org.com"
}

variable "compliance_email" {
  description = "Email for compliance notifications"
  type        = string
  default     = "compliance@healthcare-org.com"
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default = {
    Project     = "Healthcare MLOps"
    Compliance  = "HIPAA"
    ManagedBy   = "Terraform"
    Environment = "Production"
    DataClass   = "PHI"
  }
}

variable "databricks_sku" {
  description = "Databricks workspace SKU (standard, premium, trial)"
  type        = string
  default     = "premium"  # Required for HIPAA compliance
}

variable "log_retention_days" {
  description = "Log retention period in days (HIPAA requires minimum 6 years)"
  type        = number
  default     = 2190  # 6 years
}

variable "backup_retention_days" {
  description = "Backup retention period in days"
  type        = number
  default     = 90
}

variable "enable_private_endpoints" {
  description = "Enable private endpoints for all services"
  type        = bool
  default     = true
}

variable "enable_encryption_at_rest" {
  description = "Enable encryption at rest for all services"
  type        = bool
  default     = true
}

variable "enable_diagnostic_logs" {
  description = "Enable diagnostic logging for compliance"
  type        = bool
  default     = true
}
