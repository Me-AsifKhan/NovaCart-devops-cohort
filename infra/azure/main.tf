# NovaCart Azure foundation resources.
# Resources stay in the same root module so Terraform state addresses remain unchanged.

resource "azurerm_resource_group" "this" {
  name     = "rg-${var.name_prefix}"
  location = var.location
  tags     = var.tags
}

resource "azurerm_log_analytics_workspace" "this" {
  name                = "law-${var.name_prefix}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  sku                 = "PerGB2018"
  retention_in_days   = var.log_retention_days
  tags                = var.tags
}

resource "azurerm_container_registry" "this" {
  name                = var.acr_name
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  sku                 = "Basic"
  admin_enabled       = false
  tags                = var.tags
}

resource "azurerm_user_assigned_identity" "container_apps" {
  name                = "id-${var.name_prefix}-apps"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = var.tags
}

resource "azurerm_role_assignment" "acr_pull" {
  scope                = azurerm_container_registry.this.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.container_apps.principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_container_app_environment" "this" {
  name                       = "cae-${var.name_prefix}"
  location                   = azurerm_resource_group.this.location
  resource_group_name        = azurerm_resource_group.this.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id
  infrastructure_subnet_id   = var.enable_private_database ? azurerm_subnet.container_apps[0].id : null
  # Keep the environment externally addressed so the frontend remains public.
  # VNet integration is for private backend-to-PostgreSQL traffic, not to hide the storefront.
  internal_load_balancer_enabled = var.enable_private_database ? false : null

  workload_profile {
    name                  = "Consumption"
    workload_profile_type = "Consumption"
  }
  tags = var.tags

  depends_on = [
    azurerm_role_assignment.acr_pull
  ]
}

# PostgreSQL resources and development-only firewall rules (DEVOPS-011).
# PostgreSQL server, database, and development firewall configuration.
# The Azure-services firewall rule is a temporary DEV-only compromise; see DEVOPS-011.

resource "azurerm_postgresql_flexible_server" "this" {
  name                          = var.postgres_server_name
  resource_group_name           = azurerm_resource_group.this.name
  location                      = azurerm_resource_group.this.location
  version                       = "16"
  zone                          = "3"
  administrator_login           = var.db_admin_username
  administrator_password        = var.db_admin_password
  sku_name                      = var.postgres_sku_name
  storage_mb                    = var.postgres_storage_mb
  backup_retention_days         = 7
  geo_redundant_backup_enabled  = false
  delegated_subnet_id           = var.enable_private_database ? azurerm_subnet.postgres[0].id : null
  private_dns_zone_id           = var.enable_private_database ? azurerm_private_dns_zone.postgres[0].id : null
  public_network_access_enabled = !var.enable_private_database
  tags                          = var.tags

  depends_on = [
    azurerm_private_dns_zone_virtual_network_link.postgres
  ]
}

resource "azurerm_postgresql_flexible_server_database" "this" {
  name      = var.database_name
  server_id = azurerm_postgresql_flexible_server.this.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}

resource "azurerm_postgresql_flexible_server_firewall_rule" "dev_client" {
  count            = var.dev_client_ip == null || var.enable_private_database ? 0 : 1
  name             = "approved-dev-client"
  server_id        = azurerm_postgresql_flexible_server.this.id
  start_ip_address = var.dev_client_ip
  end_ip_address   = var.dev_client_ip
}

resource "azurerm_postgresql_flexible_server_firewall_rule" "allow_azure_services" {
  count = var.deploy_application && !var.enable_private_database ? 1 : 0

  name             = "allow-azure-services-dev"
  server_id        = azurerm_postgresql_flexible_server.this.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}
