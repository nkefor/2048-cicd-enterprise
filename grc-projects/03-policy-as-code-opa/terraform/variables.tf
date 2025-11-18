variable "project_name" {
  description = "Project name"
  type        = string
  default     = "policy-as-code-opa"
}

variable "environment" {
  description = "Environment (dev/staging/prod)"
  type        = string
  default     = "prod"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "notification_email" {
  description = "Email for policy violation notifications"
  type        = string
}

variable "violation_threshold" {
  description = "Threshold for violation alerts"
  type        = number
  default     = 10
}

variable "enable_opa_gatekeeper" {
  description = "Enable OPA Gatekeeper for Kubernetes"
  type        = bool
  default     = true
}

variable "policy_frameworks" {
  description = "Compliance frameworks to enforce"
  type        = list(string)
  default     = ["CIS", "PCI-DSS", "HIPAA", "SOC2"]
}
