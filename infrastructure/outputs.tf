output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.main.name
}

output "api_url" {
  description = "URL of the FastAPI application"
  value       = "https://${azurerm_linux_web_app.api.default_hostname}"
}

output "function_url" {
  description = "URL of the Azure Function"
  value       = "https://${azurerm_linux_function_app.task_processor.default_hostname}"
}

output "sql_server_name" {
  description = "Name of the SQL Server"
  value       = azurerm_mssql_server.main.name
}

output "sql_database_name" {
  description = "Name of the SQL Database"
  value       = azurerm_mssql_database.main.name
}

output "key_vault_name" {
  description = "Name of the Key Vault"
  value       = azurerm_key_vault.main.name
}