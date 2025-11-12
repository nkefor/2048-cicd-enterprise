terraform {
  required_version = ">= 1.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }

  backend "azurerm" {
    resource_group_name  = "mlops-tfstate-rg"
    storage_account_name = "mlopsplatformtfstate"
    container_name      = "tfstate"
    key                 = "mlops.terraform.tfstate"
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }

    key_vault {
      purge_soft_delete_on_destroy = true
    }
  }
}

# Main Resource Group
resource "azurerm_resource_group" "mlops" {
  name     = var.resource_group_name
  location = var.location

  tags = merge(
    var.common_tags,
    {
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  )
}

# Virtual Network
resource "azurerm_virtual_network" "mlops" {
  name                = "${var.project_name}-vnet"
  location            = azurerm_resource_group.mlops.location
  resource_group_name = azurerm_resource_group.mlops.name
  address_space       = ["10.0.0.0/16"]

  tags = var.common_tags
}

# Subnet for AKS
resource "azurerm_subnet" "aks" {
  name                 = "${var.project_name}-aks-subnet"
  resource_group_name  = azurerm_resource_group.mlops.name
  virtual_network_name = azurerm_virtual_network.mlops.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Subnet for Azure ML
resource "azurerm_subnet" "azureml" {
  name                 = "${var.project_name}-ml-subnet"
  resource_group_name  = azurerm_resource_group.mlops.name
  virtual_network_name = azurerm_virtual_network.mlops.name
  address_prefixes     = ["10.0.2.0/24"]
}

# Azure Container Registry
resource "azurerm_container_registry" "mlops" {
  name                = "${replace(var.project_name, "-", "")}acr"
  resource_group_name = azurerm_resource_group.mlops.name
  location            = azurerm_resource_group.mlops.location
  sku                 = "Premium"
  admin_enabled       = true

  georeplications {
    location                = var.secondary_location
    zone_redundancy_enabled = true
    tags                    = var.common_tags
  }

  tags = var.common_tags
}

# Log Analytics Workspace
resource "azurerm_log_analytics_workspace" "mlops" {
  name                = "${var.project_name}-logs"
  location            = azurerm_resource_group.mlops.location
  resource_group_name = azurerm_resource_group.mlops.name
  sku                 = "PerGB2018"
  retention_in_days   = 30

  tags = var.common_tags
}

# Application Insights
resource "azurerm_application_insights" "mlops" {
  name                = "${var.project_name}-appinsights"
  location            = azurerm_resource_group.mlops.location
  resource_group_name = azurerm_resource_group.mlops.name
  workspace_id        = azurerm_log_analytics_workspace.mlops.id
  application_type    = "web"

  tags = var.common_tags
}

# Storage Account for ML artifacts
resource "azurerm_storage_account" "mlops" {
  name                     = "${replace(var.project_name, "-", "")}storage"
  resource_group_name      = azurerm_resource_group.mlops.name
  location                 = azurerm_resource_group.mlops.location
  account_tier             = "Standard"
  account_replication_type = "GRS"

  blob_properties {
    versioning_enabled = true

    delete_retention_policy {
      days = 30
    }
  }

  tags = var.common_tags
}

# Storage Container for models
resource "azurerm_storage_container" "models" {
  name                  = "models"
  storage_account_name  = azurerm_storage_account.mlops.name
  container_access_type = "private"
}

# Storage Container for datasets
resource "azurerm_storage_container" "datasets" {
  name                  = "datasets"
  storage_account_name  = azurerm_storage_account.mlops.name
  container_access_type = "private"
}

# Key Vault for secrets
resource "azurerm_key_vault" "mlops" {
  name                       = "${var.project_name}-kv"
  location                   = azurerm_resource_group.mlops.location
  resource_group_name        = azurerm_resource_group.mlops.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "premium"
  soft_delete_retention_days = 7
  purge_protection_enabled   = false

  network_acls {
    default_action = "Allow"
    bypass         = "AzureServices"
  }

  tags = var.common_tags
}

data "azurerm_client_config" "current" {}

# Azure Machine Learning Workspace
resource "azurerm_machine_learning_workspace" "mlops" {
  name                    = "${var.project_name}-workspace"
  location                = azurerm_resource_group.mlops.location
  resource_group_name     = azurerm_resource_group.mlops.name
  application_insights_id = azurerm_application_insights.mlops.id
  key_vault_id            = azurerm_key_vault.mlops.id
  storage_account_id      = azurerm_storage_account.mlops.id
  container_registry_id   = azurerm_container_registry.mlops.id

  identity {
    type = "SystemAssigned"
  }

  tags = var.common_tags
}

# Azure Kubernetes Service
resource "azurerm_kubernetes_cluster" "mlops" {
  name                = "${var.project_name}-aks"
  location            = azurerm_resource_group.mlops.location
  resource_group_name = azurerm_resource_group.mlops.name
  dns_prefix          = "${var.project_name}-aks"

  default_node_pool {
    name                = "default"
    node_count          = var.aks_node_count
    vm_size             = var.aks_vm_size
    vnet_subnet_id      = azurerm_subnet.aks.id
    enable_auto_scaling = true
    min_count           = 2
    max_count           = 10
    max_pods            = 110
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin     = "azure"
    network_policy     = "azure"
    load_balancer_sku  = "standard"
    service_cidr       = "10.1.0.0/16"
    dns_service_ip     = "10.1.0.10"
  }

  oms_agent {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.mlops.id
  }

  azure_policy_enabled = true

  tags = var.common_tags
}

# Role assignment for AKS to pull from ACR
resource "azurerm_role_assignment" "aks_acr" {
  principal_id                     = azurerm_kubernetes_cluster.mlops.kubelet_identity[0].object_id
  role_definition_name             = "AcrPull"
  scope                            = azurerm_container_registry.mlops.id
  skip_service_principal_aad_check = true
}

# Cosmos DB for model metadata and A/B test results
resource "azurerm_cosmosdb_account" "mlops" {
  name                = "${var.project_name}-cosmos"
  location            = azurerm_resource_group.mlops.location
  resource_group_name = azurerm_resource_group.mlops.name
  offer_type          = "Standard"
  kind                = "GlobalDocumentDB"

  consistency_policy {
    consistency_level = "Session"
  }

  geo_location {
    location          = azurerm_resource_group.mlops.location
    failover_priority = 0
  }

  tags = var.common_tags
}

resource "azurerm_cosmosdb_sql_database" "mlops" {
  name                = "mlops"
  resource_group_name = azurerm_resource_group.mlops.name
  account_name        = azurerm_cosmosdb_account.mlops.name
}

resource "azurerm_cosmosdb_sql_container" "models" {
  name                = "models"
  resource_group_name = azurerm_resource_group.mlops.name
  account_name        = azurerm_cosmosdb_account.mlops.name
  database_name       = azurerm_cosmosdb_sql_database.mlops.name
  partition_key_path  = "/model_id"
  throughput          = 400
}

resource "azurerm_cosmosdb_sql_container" "experiments" {
  name                = "experiments"
  resource_group_name = azurerm_resource_group.mlops.name
  account_name        = azurerm_cosmosdb_account.mlops.name
  database_name       = azurerm_cosmosdb_sql_database.mlops.name
  partition_key_path  = "/experiment_id"
  throughput          = 400
}

# Azure Monitor Action Group for alerts
resource "azurerm_monitor_action_group" "mlops" {
  name                = "${var.project_name}-alerts"
  resource_group_name = azurerm_resource_group.mlops.name
  short_name          = "mlops"

  email_receiver {
    name          = "admin"
    email_address = var.alert_email
  }

  tags = var.common_tags
}

# Metric Alert for model performance degradation
resource "azurerm_monitor_metric_alert" "model_performance" {
  name                = "${var.project_name}-model-performance"
  resource_group_name = azurerm_resource_group.mlops.name
  scopes              = [azurerm_application_insights.mlops.id]
  description         = "Alert when model accuracy drops below threshold"

  criteria {
    metric_namespace = "Microsoft.Insights/components"
    metric_name      = "customMetrics/model_accuracy"
    aggregation      = "Average"
    operator         = "LessThan"
    threshold        = 0.85
  }

  action {
    action_group_id = azurerm_monitor_action_group.mlops.id
  }

  tags = var.common_tags
}
