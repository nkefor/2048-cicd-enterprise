terraform {
  required_version = ">= 1.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    databricks = {
      source  = "databricks/databricks"
      version = "~> 1.0"
    }
  }

  backend "azurerm" {
    resource_group_name  = "healthcare-mlops-tfstate-rg"
    storage_account_name = "healthcaremlopsstate"
    container_name      = "tfstate"
    key                 = "healthcare-mlops.terraform.tfstate"
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }

    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
  }
}

# Main Resource Group
resource "azurerm_resource_group" "healthcare" {
  name     = var.resource_group_name
  location = var.location

  tags = merge(
    var.common_tags,
    {
      Environment = var.environment
      Compliance  = "HIPAA"
      ManagedBy   = "Terraform"
    }
  )
}

# Virtual Network with Private Endpoints
resource "azurerm_virtual_network" "healthcare" {
  name                = "${var.project_name}-vnet"
  location            = azurerm_resource_group.healthcare.location
  resource_group_name = azurerm_resource_group.healthcare.name
  address_space       = ["10.0.0.0/16"]

  tags = merge(var.common_tags, { Purpose = "HIPAA-Compliant-Network" })
}

# Subnet for Databricks - Public
resource "azurerm_subnet" "databricks_public" {
  name                 = "${var.project_name}-databricks-public"
  resource_group_name  = azurerm_resource_group.healthcare.name
  virtual_network_name = azurerm_virtual_network.healthcare.name
  address_prefixes     = ["10.0.1.0/24"]

  delegation {
    name = "databricks-delegation"

    service_delegation {
      name = "Microsoft.Databricks/workspaces"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
        "Microsoft.Network/virtualNetworks/subnets/prepareNetworkPolicies/action",
        "Microsoft.Network/virtualNetworks/subnets/unprepareNetworkPolicies/action"
      ]
    }
  }
}

# Subnet for Databricks - Private
resource "azurerm_subnet" "databricks_private" {
  name                 = "${var.project_name}-databricks-private"
  resource_group_name  = azurerm_resource_group.healthcare.name
  virtual_network_name = azurerm_virtual_network.healthcare.name
  address_prefixes     = ["10.0.2.0/24"]

  delegation {
    name = "databricks-delegation"

    service_delegation {
      name = "Microsoft.Databricks/workspaces"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
        "Microsoft.Network/virtualNetworks/subnets/prepareNetworkPolicies/action",
        "Microsoft.Network/virtualNetworks/subnets/unprepareNetworkPolicies/action"
      ]
    }
  }
}

# Network Security Group for Databricks
resource "azurerm_network_security_group" "databricks" {
  name                = "${var.project_name}-databricks-nsg"
  location            = azurerm_resource_group.healthcare.location
  resource_group_name = azurerm_resource_group.healthcare.name

  tags = var.common_tags
}

# Associate NSG with Databricks Public Subnet
resource "azurerm_subnet_network_security_group_association" "databricks_public" {
  subnet_id                 = azurerm_subnet.databricks_public.id
  network_security_group_id = azurerm_network_security_group.databricks.id
}

# Associate NSG with Databricks Private Subnet
resource "azurerm_subnet_network_security_group_association" "databricks_private" {
  subnet_id                 = azurerm_subnet.databricks_private.id
  network_security_group_id = azurerm_network_security_group.databricks.id
}

# Azure Databricks Workspace (HIPAA-Compliant)
resource "azurerm_databricks_workspace" "healthcare" {
  name                        = "${var.project_name}-databricks"
  resource_group_name         = azurerm_resource_group.healthcare.name
  location                    = azurerm_resource_group.healthcare.location
  sku                         = "premium"  # Required for HIPAA compliance features
  managed_resource_group_name = "${var.project_name}-databricks-managed-rg"

  custom_parameters {
    no_public_ip                                         = true
    virtual_network_id                                   = azurerm_virtual_network.healthcare.id
    public_subnet_name                                   = azurerm_subnet.databricks_public.name
    private_subnet_name                                  = azurerm_subnet.databricks_private.name
    public_subnet_network_security_group_association_id  = azurerm_subnet_network_security_group_association.databricks_public.id
    private_subnet_network_security_group_association_id = azurerm_subnet_network_security_group_association.databricks_private.id
  }

  tags = merge(var.common_tags, {
    Compliance = "HIPAA"
    DataClass  = "PHI"
  })
}

# Storage Account for Medical Imaging (HIPAA-Compliant)
resource "azurerm_storage_account" "medical_imaging" {
  name                     = "${replace(var.project_name, "-", "")}imaging"
  resource_group_name      = azurerm_resource_group.healthcare.name
  location                 = azurerm_resource_group.healthcare.location
  account_tier             = "Premium"
  account_replication_type = "GRS"  # Geo-redundant for DR
  account_kind             = "BlockBlobStorage"

  # HIPAA Compliance Features
  enable_https_traffic_only       = true
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false

  # Encryption
  infrastructure_encryption_enabled = true

  blob_properties {
    versioning_enabled = true

    delete_retention_policy {
      days = 90  # HIPAA requires 90-day retention
    }

    container_delete_retention_policy {
      days = 90
    }
  }

  # Network Rules - Private Access Only
  network_rules {
    default_action = "Deny"
    bypass         = ["AzureServices"]
  }

  tags = merge(var.common_tags, {
    Compliance = "HIPAA"
    DataClass  = "PHI"
    Purpose    = "MedicalImaging"
  })
}

# Storage Containers for Medical Data
resource "azurerm_storage_container" "dicom_images" {
  name                  = "dicom-images"
  storage_account_name  = azurerm_storage_account.medical_imaging.name
  container_access_type = "private"
}

resource "azurerm_storage_container" "processed_images" {
  name                  = "processed-images"
  storage_account_name  = azurerm_storage_account.medical_imaging.name
  container_access_type = "private"
}

resource "azurerm_storage_container" "model_artifacts" {
  name                  = "model-artifacts"
  storage_account_name  = azurerm_storage_account.medical_imaging.name
  container_access_type = "private"
}

# Storage Account for Audit Logs (HIPAA Requirement)
resource "azurerm_storage_account" "audit_logs" {
  name                     = "${replace(var.project_name, "-", "")}audit"
  resource_group_name      = azurerm_resource_group.healthcare.name
  location                 = azurerm_resource_group.healthcare.location
  account_tier             = "Standard"
  account_replication_type = "GRS"

  enable_https_traffic_only         = true
  min_tls_version                   = "TLS1_2"
  infrastructure_encryption_enabled = true

  blob_properties {
    versioning_enabled = true

    delete_retention_policy {
      days = 2555  # 7 years for HIPAA audit logs
    }
  }

  tags = merge(var.common_tags, {
    Compliance = "HIPAA"
    Purpose    = "AuditLogs"
  })
}

# Key Vault for Encryption Keys and Secrets (HIPAA-Compliant)
resource "azurerm_key_vault" "healthcare" {
  name                       = "${var.project_name}-kv"
  location                   = azurerm_resource_group.healthcare.location
  resource_group_name        = azurerm_resource_group.healthcare.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "premium"  # HSM-backed for HIPAA
  soft_delete_retention_days = 90
  purge_protection_enabled   = true  # HIPAA requirement

  # Network ACLs
  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
  }

  # Enable logging for audit
  enabled_for_disk_encryption     = true
  enabled_for_deployment          = true
  enabled_for_template_deployment = true

  tags = merge(var.common_tags, {
    Compliance = "HIPAA"
    Purpose    = "Encryption"
  })
}

data "azurerm_client_config" "current" {}

# Log Analytics Workspace for Security Monitoring
resource "azurerm_log_analytics_workspace" "healthcare" {
  name                = "${var.project_name}-logs"
  location            = azurerm_resource_group.healthcare.location
  resource_group_name = azurerm_resource_group.healthcare.name
  sku                 = "PerGB2018"
  retention_in_days   = 365  # 1 year minimum for HIPAA

  tags = merge(var.common_tags, {
    Compliance = "HIPAA"
    Purpose    = "SecurityMonitoring"
  })
}

# Application Insights for Model Monitoring
resource "azurerm_application_insights" "healthcare" {
  name                = "${var.project_name}-appinsights"
  location            = azurerm_resource_group.healthcare.location
  resource_group_name = azurerm_resource_group.healthcare.name
  workspace_id        = azurerm_log_analytics_workspace.healthcare.id
  application_type    = "web"
  retention_in_days   = 365  # HIPAA compliance

  tags = merge(var.common_tags, {
    Compliance = "HIPAA"
  })
}

# Azure Machine Learning Workspace
resource "azurerm_machine_learning_workspace" "healthcare" {
  name                    = "${var.project_name}-ml-workspace"
  location                = azurerm_resource_group.healthcare.location
  resource_group_name     = azurerm_resource_group.healthcare.name
  application_insights_id = azurerm_application_insights.healthcare.id
  key_vault_id            = azurerm_key_vault.healthcare.id
  storage_account_id      = azurerm_storage_account.medical_imaging.id

  identity {
    type = "SystemAssigned"
  }

  # HIPAA Compliance
  public_network_access_enabled = false
  high_business_impact          = true  # Enables additional security features

  encryption {
    key_vault_id = azurerm_key_vault.healthcare.id
    key_id       = azurerm_key_vault_key.ml_encryption.id
  }

  tags = merge(var.common_tags, {
    Compliance = "HIPAA"
    DataClass  = "PHI"
  })
}

# Encryption Key for ML Workspace
resource "azurerm_key_vault_key" "ml_encryption" {
  name         = "ml-encryption-key"
  key_vault_id = azurerm_key_vault.healthcare.id
  key_type     = "RSA-HSM"  # Hardware Security Module
  key_size     = 4096

  key_opts = [
    "decrypt",
    "encrypt",
    "sign",
    "unwrapKey",
    "verify",
    "wrapKey",
  ]

  depends_on = [azurerm_key_vault.healthcare]
}

# Cosmos DB for Model Registry and Audit Trail
resource "azurerm_cosmosdb_account" "healthcare" {
  name                = "${var.project_name}-cosmos"
  location            = azurerm_resource_group.healthcare.location
  resource_group_name = azurerm_resource_group.healthcare.name
  offer_type          = "Standard"
  kind                = "GlobalDocumentDB"

  # HIPAA Compliance
  public_network_access_enabled = false
  local_authentication_disabled = false

  consistency_policy {
    consistency_level = "Strong"  # Ensures data integrity
  }

  geo_location {
    location          = azurerm_resource_group.healthcare.location
    failover_priority = 0
    zone_redundant    = true
  }

  # Backup for DR
  backup {
    type                = "Continuous"
    interval_in_minutes = 240
    retention_in_hours  = 720  # 30 days
  }

  tags = merge(var.common_tags, {
    Compliance = "HIPAA"
    Purpose    = "ModelRegistry"
  })
}

# Cosmos DB Database
resource "azurerm_cosmosdb_sql_database" "healthcare" {
  name                = "healthcare-mlops"
  resource_group_name = azurerm_resource_group.healthcare.name
  account_name        = azurerm_cosmosdb_account.healthcare.name
}

# Cosmos DB Containers
resource "azurerm_cosmosdb_sql_container" "models" {
  name                = "models"
  resource_group_name = azurerm_resource_group.healthcare.name
  account_name        = azurerm_cosmosdb_account.healthcare.name
  database_name       = azurerm_cosmosdb_sql_database.healthcare.name
  partition_key_path  = "/model_id"
  throughput          = 400
}

resource "azurerm_cosmosdb_sql_container" "audit_trail" {
  name                = "audit_trail"
  resource_group_name = azurerm_resource_group.healthcare.name
  account_name        = azurerm_cosmosdb_account.healthcare.name
  database_name       = azurerm_cosmosdb_sql_database.healthcare.name
  partition_key_path  = "/event_id"
  throughput          = 400
}

resource "azurerm_cosmosdb_sql_container" "model_versions" {
  name                = "model_versions"
  resource_group_name = azurerm_resource_group.healthcare.name
  account_name        = azurerm_cosmosdb_account.healthcare.name
  database_name       = azurerm_cosmosdb_sql_database.healthcare.name
  partition_key_path  = "/version_id"
  throughput          = 400
}

# Azure Monitor Diagnostic Settings for HIPAA Audit
resource "azurerm_monitor_diagnostic_setting" "storage_diagnostics" {
  name                       = "storage-diagnostics"
  target_resource_id         = azurerm_storage_account.medical_imaging.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.healthcare.id

  enabled_log {
    category = "StorageRead"
  }

  enabled_log {
    category = "StorageWrite"
  }

  enabled_log {
    category = "StorageDelete"
  }

  metric {
    category = "Transaction"
  }
}

# Security Center (Compliance Monitoring)
resource "azurerm_security_center_subscription_pricing" "healthcare" {
  tier          = "Standard"
  resource_type = "VirtualMachines"
}

# Action Group for HIPAA Alerts
resource "azurerm_monitor_action_group" "hipaa_alerts" {
  name                = "${var.project_name}-hipaa-alerts"
  resource_group_name = azurerm_resource_group.healthcare.name
  short_name          = "hipaa"

  email_receiver {
    name                    = "security-team"
    email_address           = var.security_email
    use_common_alert_schema = true
  }

  email_receiver {
    name                    = "compliance-team"
    email_address           = var.compliance_email
    use_common_alert_schema = true
  }

  tags = var.common_tags
}

# Alert for Unauthorized Access Attempts
resource "azurerm_monitor_activity_log_alert" "unauthorized_access" {
  name                = "${var.project_name}-unauthorized-access"
  resource_group_name = azurerm_resource_group.healthcare.name
  scopes              = [azurerm_resource_group.healthcare.id]
  description         = "Alert on unauthorized access attempts to PHI data"

  criteria {
    category       = "Security"
    operation_name = "Microsoft.Storage/storageAccounts/blobServices/containers/blobs/read"
    level          = "Error"
  }

  action {
    action_group_id = azurerm_monitor_action_group.hipaa_alerts.id
  }

  tags = var.common_tags
}
