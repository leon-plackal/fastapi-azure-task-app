variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
}

variable "prefix" {
  description = "Prefix for resource names"
  type        = string
  default     = "taskapi"
}

variable "location" {
  description = "Azure region to deploy resources"
  type        = string
  default     = "Canada Central"
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default = {
    Environment = "Development"
    Project     = "Task API"
    ManagedBy   = "Terraform"
  }
}

variable "sql_admin_username" {
  description = "Username for the SQL Server administrator"
  type        = string
  sensitive   = true
}

variable "sql_admin_password" {
  description = "Password for the SQL Server administrator"
  type        = string
  sensitive   = true
}

variable "my_ip_address" {
  description = "Public IP address to allow access to the SQL Server"
  type        = string
}

variable "aad_admin_object_id" {
  description = "Object ID of the Azure AD user or group for SQL admin"
  type        = string
}

variable "azure_tenant_id" {
  description = "Azure AD tenant ID"
  type        = string
}

variable "azure_client_id" {
  description = "Azure AD application client ID for authentication"
  type        = string
}

variable "azure_client_secret" {
  description = "Azure AD application client secret for authentication"
  type        = string
  sensitive   = true
}