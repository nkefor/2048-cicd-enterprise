variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "mlops-platform"
}

variable "resource_group_name" {
  description = "Name of the Azure resource group"
  type        = string
  default     = "mlops-platform-rg"
}

variable "location" {
  description = "Primary Azure region"
  type        = string
  default     = "eastus"
}

variable "secondary_location" {
  description = "Secondary Azure region for geo-replication"
  type        = string
  default     = "westus2"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "prod"
}

variable "aks_node_count" {
  description = "Initial number of nodes in AKS cluster"
  type        = number
  default     = 3
}

variable "aks_vm_size" {
  description = "VM size for AKS nodes"
  type        = string
  default     = "Standard_D4s_v3"
}

variable "alert_email" {
  description = "Email address for alerts"
  type        = string
  default     = "mlops-admin@example.com"
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    Project     = "MLOps Platform"
    ManagedBy   = "Terraform"
    Environment = "Production"
  }
}

variable "enable_monitoring" {
  description = "Enable advanced monitoring and alerting"
  type        = bool
  default     = true
}

variable "enable_ab_testing" {
  description = "Enable A/B testing infrastructure"
  type        = bool
  default     = true
}

variable "model_serving_replicas" {
  description = "Number of model serving replicas"
  type        = number
  default     = 3
}
