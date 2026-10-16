output "resource_group_name" {
  description = "Development resource group."
  value       = azurerm_resource_group.this.name
}

output "location" {
  description = "Azure region used by the baseline."
  value       = azurerm_resource_group.this.location
}

output "log_analytics_workspace_id" {
  description = "Log Analytics workspace resource ID."
  value       = azurerm_log_analytics_workspace.this.id
}

output "container_apps_environment_id" {
  description = "Container Apps environment resource ID; application apps are intentionally not deployed in DEVOPS-008."
  value       = azurerm_container_app_environment.this.id
}

output "container_registry_login_server" {
  description = "ACR endpoint for later application image publishing and pulls."
  value       = azurerm_container_registry.this.login_server
}

output "container_apps_identity_client_id" {
  description = "Client ID of the user-assigned runtime identity."
  value       = azurerm_user_assigned_identity.container_apps.client_id
}

output "postgresql_server_fqdn" {
  description = "PostgreSQL server hostname. Firewall access must be explicitly configured."
  value       = azurerm_postgresql_flexible_server.this.fqdn
}

output "postgresql_database_name" {
  description = "Development database name."
  value       = azurerm_postgresql_flexible_server_database.this.name
}

output "frontend_url" {
  description = "Public frontend URL; null until deploy_application is enabled."
  value       = var.deploy_application ? "https://${azurerm_container_app.frontend[0].ingress[0].fqdn}" : null
}

output "backend_internal_fqdn" {
  description = "Internal backend FQDN; null until deploy_application is enabled."
  value       = var.deploy_application ? azurerm_container_app.backend[0].ingress[0].fqdn : null
}

output "private_database_enabled" {
  description = "Whether the DEVOPS-011 private database network mode is enabled."
  value       = var.enable_private_database
}