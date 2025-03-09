terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "4.22.0"
    }
  }
}

provider "azurerm" {
  subscription_id = var.subscription_id
  features {}
}

# Random suffix for unique resource names
resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

# Resource Group
resource "azurerm_resource_group" "main" {
  name     = "${var.prefix}-rg"
  location = var.location
  tags     = var.tags
}

# Virtual Network
resource "azurerm_virtual_network" "main" {
  name                = "${var.prefix}-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = var.tags
}

# Subnets
resource "azurerm_subnet" "app" {
  name                 = "app-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.1.0/24"]
  service_endpoints    = ["Microsoft.Sql"]
}

resource "azurerm_subnet" "function" {
  name                 = "function-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.2.0/24"]
  delegation {
    name = "delegation"
    service_delegation {
      name    = "Microsoft.Web/serverFarms"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
  service_endpoints = ["Microsoft.Sql"]
}

# Azure SQL Server
resource "azurerm_mssql_server" "main" {
  name                         = "${var.prefix}-sqlserver-${random_string.suffix.result}"
  resource_group_name          = azurerm_resource_group.main.name
  location                     = azurerm_resource_group.main.location
  version                      = "12.0"
  administrator_login          = var.sql_admin_username
  administrator_login_password = var.sql_admin_password
  tags                         = var.tags
  
  azuread_administrator {
    login_username = "AzureAD Admin"
    object_id      = var.aad_admin_object_id
  }
}

# Azure SQL Database
resource "azurerm_mssql_database" "main" {
  name                = "${var.prefix}-db"
  server_id           = azurerm_mssql_server.main.id
  collation           = "SQL_Latin1_General_CP1_CI_AS"
  max_size_gb         = 4
  sku_name            = "Basic"
  tags                = var.tags
}

# Virtual Network Rule for SQL Server
resource "azurerm_mssql_virtual_network_rule" "app_subnet" {
  name      = "app-subnet-rule"
  server_id = azurerm_mssql_server.main.id
  subnet_id = azurerm_subnet.app.id
}

resource "azurerm_mssql_virtual_network_rule" "function_subnet" {
  name      = "function-subnet-rule"
  server_id = azurerm_mssql_server.main.id
  subnet_id = azurerm_subnet.function.id
}

# App Service Plan
resource "azurerm_service_plan" "main" {
  name                = "${var.prefix}-app-plan"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  os_type             = "Linux"
  # free tier
  sku_name            = "F1"
  tags                = var.tags
}

# App Service for FastAPI
resource "azurerm_linux_web_app" "api" {
  name                = "${var.prefix}-api-${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  service_plan_id     = azurerm_service_plan.main.id
  tags                = var.tags
  
  site_config {
    application_stack {
      python_version = "3.10"
    }
    always_on = true
  }
  
  app_settings = {
    "SCM_DO_BUILD_DURING_DEPLOYMENT" = "true"
    "DB_SERVER"                      = azurerm_mssql_server.main.fully_qualified_domain_name
    "DB_NAME"                        = azurerm_mssql_database.main.name
    "DB_USER"                        = var.sql_admin_username
    "DB_PASSWORD"                    = var.sql_admin_password
    "DB_DRIVER"                      = "ODBC Driver 17 for SQL Server"
    "FUNCTION_URL"                   = "https://${azurerm_linux_function_app.task_processor.default_hostname}"
    "FUNCTION_KEY"                   = ""  # This will be populated post-deployment
    "AZURE_TENANT_ID"                = var.azure_tenant_id
    "AZURE_CLIENT_ID"                = var.azure_client_id
    "AZURE_CLIENT_SECRET"            = var.azure_client_secret
    "WEBSITES_PORT"                  = "8000"
  }
  
  virtual_network_subnet_id = azurerm_subnet.app.id
}

# Storage Account for Function App
resource "azurerm_storage_account" "function" {
  name                     = "${var.prefix}funcsa${random_string.suffix.result}"
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  tags                     = var.tags
}

# Function App Service Plan
resource "azurerm_service_plan" "function" {
  name                = "${var.prefix}-function-plan"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  os_type             = "Linux"
  sku_name            = "F1"  # Free tier
  tags                = var.tags
}

# Function App
resource "azurerm_linux_function_app" "task_processor" {
  name                       = "${var.prefix}-func-${random_string.suffix.result}"
  resource_group_name        = azurerm_resource_group.main.name
  location                   = azurerm_resource_group.main.location
  service_plan_id            = azurerm_service_plan.function.id
  storage_account_name       = azurerm_storage_account.function.name
  storage_account_access_key = azurerm_storage_account.function.primary_access_key
  tags                       = var.tags
  
  site_config {
    application_stack {
      python_version = "3.10"
    }
  }
  
  app_settings = {
    "WEBSITE_RUN_FROM_PACKAGE"    = "1"
    "FUNCTIONS_WORKER_RUNTIME"    = "python"
    "DB_SERVER"                   = azurerm_mssql_server.main.fully_qualified_domain_name
    "DB_NAME"                     = azurerm_mssql_database.main.name
    "DB_USER"                     = var.sql_admin_username
    "DB_PASSWORD"                 = var.sql_admin_password
    "DB_DRIVER"                   = "ODBC Driver 17 for SQL Server"
    "AzureWebJobsStorage"         = azurerm_storage_account.function.primary_connection_string
    "AZURE_TENANT_ID"             = var.azure_tenant_id
    "AZURE_CLIENT_ID"             = var.azure_client_id
    "AZURE_CLIENT_SECRET"         = var.azure_client_secret
  }
  
  virtual_network_subnet_id = azurerm_subnet.function.id
}

# Key Vault for secrets
resource "azurerm_key_vault" "main" {
  name                        = "${var.prefix}-kv-${random_string.suffix.result}"
  location                    = azurerm_resource_group.main.location
  resource_group_name         = azurerm_resource_group.main.name
  enabled_for_disk_encryption = true
  tenant_id                   = var.azure_tenant_id
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false
  sku_name                    = "standard"
  tags                        = var.tags
  
  access_policy {
    tenant_id = var.azure_tenant_id
    object_id = var.aad_admin_object_id
    
    key_permissions = [
      "Get", "List", "Create", "Delete"
    ]
    secret_permissions = [
      "Get", "List", "Set", "Delete"
    ]
  }
}

# Store secrets in Key Vault
resource "azurerm_key_vault_secret" "db_connection" {
  name         = "db-connection-string"
  value        = "Driver={ODBC Driver 17 for SQL Server};Server=tcp:${azurerm_mssql_server.main.fully_qualified_domain_name},1433;Database=${azurerm_mssql_database.main.name};Uid=${var.sql_admin_username};Pwd=${var.sql_admin_password};Encrypt=yes;TrustServerCertificate=no;Connection Timeout=30;"
  key_vault_id = azurerm_key_vault.main.id
}