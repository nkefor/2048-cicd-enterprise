# Governance Module Variables

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "organization_id" {
  description = "AWS Organization ID (leave empty if not using AWS Organizations)"
  type        = string
  default     = ""
}

variable "allowed_regions" {
  description = "List of allowed AWS regions"
  type        = list(string)
  default     = ["us-east-1", "us-west-2"]
}

variable "require_mfa" {
  description = "Require MFA for sensitive operations"
  type        = bool
  default     = true
}

variable "require_encryption" {
  description = "Require encryption for all data at rest"
  type        = bool
  default     = true
}
