output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.healthcare.name
}

output "databricks_workspace_url" {
  description = "URL of the Databricks workspace"
  value       = azurerm_databricks_workspace.healthcare.workspace_url
}

output "databricks_workspace_id" {
  description = "ID of the Databricks workspace"
  value       = azurerm_databricks_workspace.healthcare.workspace_id
}

output "storage_account_name" {
  description = "Name of the medical imaging storage account"
  value       = azurerm_storage_account.medical_imaging.name
}

output "storage_account_primary_key" {
  description = "Primary key for medical imaging storage"
  value       = azurerm_storage_account.medical_imaging.primary_access_key
  sensitive   = true
}

output "key_vault_name" {
  description = "Name of the Key Vault"
  value       = azurerm_key_vault.healthcare.name
}

output "key_vault_uri" {
  description = "URI of the Key Vault"
  value       = azurerm_key_vault.healthcare.vault_uri
}

output "ml_workspace_name" {
  description = "Name of the Azure ML workspace"
  value       = azurerm_machine_learning_workspace.healthcare.name
}

output "ml_workspace_id" {
  description = "ID of the Azure ML workspace"
  value       = azurerm_machine_learning_workspace.healthcare.id
}

output "cosmos_db_endpoint" {
  description = "Cosmos DB endpoint"
  value       = azurerm_cosmosdb_account.healthcare.endpoint
}

output "cosmos_db_primary_key" {
  description = "Cosmos DB primary key"
  value       = azurerm_cosmosdb_account.healthcare.primary_key
  sensitive   = true
}

output "app_insights_instrumentation_key" {
  description = "Application Insights instrumentation key"
  value       = azurerm_application_insights.healthcare.instrumentation_key
  sensitive   = true
}

output "app_insights_connection_string" {
  description = "Application Insights connection string"
  value       = azurerm_application_insights.healthcare.connection_string
  sensitive   = true
}

output "log_analytics_workspace_id" {
  description = "Log Analytics workspace ID"
  value       = azurerm_log_analytics_workspace.healthcare.id
}

output "audit_storage_account_name" {
  description = "Name of the audit logs storage account"
  value       = azurerm_storage_account.audit_logs.name
}
