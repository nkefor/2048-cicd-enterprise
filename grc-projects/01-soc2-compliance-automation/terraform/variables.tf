variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "soc2-compliance"
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
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

# Evidence Collection Settings
variable "evidence_retention_days" {
  description = "Number of days to retain compliance evidence"
  type        = number
  default     = 2555 # 7 years for SOC 2 compliance
}

variable "scan_frequency_minutes" {
  description = "How often to run compliance scans (in minutes)"
  type        = number
  default     = 60 # Hourly scans
}

# Alerting Configuration
variable "alert_email" {
  description = "Email address for compliance alerts"
  type        = string
}

variable "alert_slack_webhook" {
  description = "Slack webhook URL for alerts (optional)"
  type        = string
  default     = ""
}

# Compliance Thresholds
variable "compliance_score_threshold" {
  description = "Minimum compliance score before alerting (0-100)"
  type        = number
  default     = 85

  validation {
    condition     = var.compliance_score_threshold >= 0 && var.compliance_score_threshold <= 100
    error_message = "Compliance score threshold must be between 0 and 100."
  }
}

variable "critical_finding_threshold" {
  description = "Maximum number of critical findings before alerting"
  type        = number
  default     = 5
}

# Lambda Configuration
variable "lambda_memory_size" {
  description = "Memory size for Lambda functions (MB)"
  type        = number
  default     = 512
}

variable "lambda_timeout" {
  description = "Timeout for Lambda functions (seconds)"
  type        = number
  default     = 300
}

variable "lambda_runtime" {
  description = "Python runtime version for Lambda"
  type        = string
  default     = "python3.11"
}

# DynamoDB Configuration
variable "dynamodb_read_capacity" {
  description = "DynamoDB read capacity units"
  type        = number
  default     = 5
}

variable "dynamodb_write_capacity" {
  description = "DynamoDB write capacity units"
  type        = number
  default     = 5
}

variable "enable_point_in_time_recovery" {
  description = "Enable DynamoDB point-in-time recovery"
  type        = bool
  default     = true
}

# Multi-Account Scanning
variable "target_accounts" {
  description = "List of AWS account IDs to scan for compliance"
  type        = list(string)
  default     = []
}

variable "assume_role_name" {
  description = "IAM role name to assume in target accounts"
  type        = string
  default     = "SOC2ComplianceScanner"
}

# SOC 2 Control Categories
variable "enabled_trust_principles" {
  description = "SOC 2 Trust Service Criteria to monitor"
  type        = list(string)
  default = [
    "security",
    "availability",
    "processing_integrity",
    "confidentiality",
    "privacy"
  ]
}

# Additional Compliance Frameworks
variable "enable_hipaa_controls" {
  description = "Enable HIPAA-specific compliance controls"
  type        = bool
  default     = false
}

variable "enable_pci_dss_controls" {
  description = "Enable PCI DSS compliance controls"
  type        = bool
  default     = false
}

variable "enable_gdpr_controls" {
  description = "Enable GDPR compliance controls"
  type        = bool
  default     = false
}

# Cost Optimization
variable "enable_lambda_reserved_concurrency" {
  description = "Enable reserved concurrency for Lambda functions"
  type        = bool
  default     = false
}

variable "reserved_concurrency_limit" {
  description = "Reserved concurrency limit for Lambda functions"
  type        = number
  default     = 10
}

# Tagging
variable "additional_tags" {
  description = "Additional tags for all resources"
  type        = map(string)
  default     = {}
}
