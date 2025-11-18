variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "aws-security-audit"
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

variable "primary_region" {
  description = "Primary AWS region for Security Hub aggregation"
  type        = string
  default     = "us-east-1"
}

variable "secondary_region" {
  description = "Secondary AWS region for multi-region deployment"
  type        = string
  default     = "us-west-2"
}

variable "security_hub_regions" {
  description = "List of regions to enable Security Hub"
  type        = list(string)
  default     = ["us-east-1", "us-west-2", "eu-west-1"]
}

variable "organization_id" {
  description = "AWS Organization ID for multi-account governance"
  type        = string
  default     = ""
}

variable "delegated_admin_account_id" {
  description = "Account ID for Security Hub delegated administrator"
  type        = string
  default     = ""
}

variable "member_account_ids" {
  description = "List of AWS account IDs to monitor"
  type        = list(string)
  default     = []
}

variable "notification_email" {
  description = "Email address for security notifications"
  type        = string
}

variable "slack_webhook_url" {
  description = "Slack webhook URL for notifications (optional)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "pagerduty_integration_key" {
  description = "PagerDuty integration key for critical alerts (optional)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "auto_remediate_critical" {
  description = "Enable auto-remediation for CRITICAL severity findings"
  type        = bool
  default     = true
}

variable "auto_remediate_high" {
  description = "Enable auto-remediation for HIGH severity findings"
  type        = bool
  default     = true
}

variable "auto_remediate_medium" {
  description = "Enable auto-remediation for MEDIUM severity findings"
  type        = bool
  default     = false
}

variable "auto_remediate_low" {
  description = "Enable auto-remediation for LOW severity findings"
  type        = bool
  default     = false
}

variable "enabled_standards" {
  description = "List of Security Hub standards to enable"
  type        = list(string)
  default     = [
    "aws-foundational-security-best-practices/v/1.0.0",
    "cis-aws-foundations-benchmark/v/1.4.0",
    "pci-dss/v/3.2.1"
  ]
}

variable "cis_benchmark_version" {
  description = "CIS AWS Foundations Benchmark version"
  type        = string
  default     = "1.4.0"
}

variable "evidence_retention_days" {
  description = "Number of days to retain evidence in S3"
  type        = number
  default     = 2555  # 7 years

  validation {
    condition     = var.evidence_retention_days >= 365
    error_message = "Evidence retention must be at least 1 year."
  }
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 90

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.log_retention_days)
    error_message = "Log retention days must be a valid CloudWatch Logs retention period."
  }
}

variable "enable_guardduty" {
  description = "Enable AWS GuardDuty for threat detection"
  type        = bool
  default     = true
}

variable "enable_inspector" {
  description = "Enable AWS Inspector for vulnerability assessment"
  type        = bool
  default     = true
}

variable "enable_config" {
  description = "Enable AWS Config for resource compliance"
  type        = bool
  default     = true
}

variable "compliance_threshold" {
  description = "Minimum compliance score threshold (0-100)"
  type        = number
  default     = 95

  validation {
    condition     = var.compliance_threshold >= 0 && var.compliance_threshold <= 100
    error_message = "Compliance threshold must be between 0 and 100."
  }
}

variable "max_findings_age_days" {
  description = "Maximum age of findings before auto-archiving"
  type        = number
  default     = 90
}

variable "critical_finding_sla_hours" {
  description = "SLA for remediating critical findings (hours)"
  type        = number
  default     = 4
}

variable "high_finding_sla_hours" {
  description = "SLA for remediating high severity findings (hours)"
  type        = number
  default     = 24
}

variable "medium_finding_sla_hours" {
  description = "SLA for remediating medium severity findings (hours)"
  type        = number
  default     = 168  # 1 week
}

variable "enable_auto_enable_standards" {
  description = "Automatically enable Security Hub standards in all accounts"
  type        = bool
  default     = true
}

variable "suppression_rules" {
  description = "Map of suppression rules for approved exceptions"
  type = map(object({
    rule_id          = string
    finding_type     = string
    resource_pattern = string
    reason           = string
    approved_by      = string
    expiration_date  = string
  }))
  default = {}
}

variable "custom_controls" {
  description = "Map of custom security controls"
  type = map(object({
    title        = string
    description  = string
    severity     = string
    auto_remediate = bool
  }))
  default = {}
}

variable "compliance_frameworks" {
  description = "List of compliance frameworks to map"
  type        = list(string)
  default     = ["CIS", "PCI-DSS", "NIST", "HIPAA", "SOC2"]
}

variable "enable_quicksight_dashboard" {
  description = "Enable QuickSight dashboard for compliance reporting"
  type        = bool
  default     = true
}

variable "quicksight_admin_user" {
  description = "QuickSight admin user ARN"
  type        = string
  default     = ""
}

variable "enable_athena_queries" {
  description = "Enable Athena for ad-hoc compliance queries"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
