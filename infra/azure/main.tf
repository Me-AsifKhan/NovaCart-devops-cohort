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
  name                           = "cae-${var.name_prefix}"
  location                       = azurerm_resource_group.this.location
  resource_group_name            = azurerm_resource_group.this.name
  log_analytics_workspace_id     = azurerm_log_analytics_workspace.this.id
  infrastructure_subnet_id       = var.enable_private_database ? azurerm_subnet.container_apps[0].id : null
  internal_load_balancer_enabled = false

  workload_profile {
    name                  = "Consumption"
    workload_profile_type = "Consumption"
  }
  tags = var.tags

  depends_on = [
    azurerm_role_assignment.acr_pull
  ]
}

resource "azurerm_postgresql_flexible_server" "this" {
  name                          = var.postgres_server_name
  resource_group_name           = azurerm_resource_group.this.name
  location                      = azurerm_resource_group.this.location
  version                       = "16"
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

# Optional VNet used by DEVOPS-011. The Container Apps subnet is dedicated to
# the environment; PostgreSQL uses a separate delegated subnet and private DNS.
resource "azurerm_virtual_network" "private" {
  count               = var.enable_private_database ? 1 : 0
  name                = "vnet-${var.name_prefix}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  address_space       = ["10.42.0.0/16"]
  tags                = var.tags
}

resource "azurerm_subnet" "container_apps" {
  count                = var.enable_private_database ? 1 : 0
  name                 = "snet-container-apps"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.private[0].name
  address_prefixes     = ["10.42.0.0/23"]
  delegation {
    name = "container-apps"
    service_delegation {
      name    = "Microsoft.App/environments"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

resource "azurerm_subnet" "postgres" {
  count                = var.enable_private_database ? 1 : 0
  name                 = "snet-postgres"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.private[0].name
  address_prefixes     = ["10.42.2.0/28"]
  delegation {
    name = "postgres-flexible-server"
    service_delegation {
      name    = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

resource "azurerm_private_dns_zone" "postgres" {
  count               = var.enable_private_database ? 1 : 0
  name                = "private.postgres.database.azure.com"
  resource_group_name = azurerm_resource_group.this.name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "postgres" {
  count                 = var.enable_private_database ? 1 : 0
  name                  = "link-${var.name_prefix}-postgres"
  private_dns_zone_name = azurerm_private_dns_zone.postgres[0].name
  virtual_network_id    = azurerm_virtual_network.private[0].id
  resource_group_name   = azurerm_resource_group.this.name
  registration_enabled  = false
  tags                  = var.tags
}

# Container Apps are optional for the first Terraform pass. Create the base
# platform, build/push images, then set deploy_application=true for the next pass.
resource "azurerm_container_app" "backend" {
  count                        = var.deploy_application ? 1 : 0
  name                         = "ca-${var.name_prefix}-backend"
  container_app_environment_id = azurerm_container_app_environment.this.id
  resource_group_name          = azurerm_resource_group.this.name
  revision_mode                = "Single"
  tags                         = var.tags

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.container_apps.id]
  }

  registry {
    server   = azurerm_container_registry.this.login_server
    identity = azurerm_user_assigned_identity.container_apps.id
  }

  secret {
    name  = "database-url"
    value = "postgresql://${var.db_admin_username}:${urlencode(var.db_admin_password)}@${azurerm_postgresql_flexible_server.this.fqdn}:5432/${var.database_name}?sslmode=require"
  }

  template {
    # Scale-to-zero avoids the backend starting before its narrow PostgreSQL
    # egress firewall rules have been created during the same Terraform apply.
    min_replicas = 0
    max_replicas = 2
    container {
      name   = "novacart-backend"
      image  = "${azurerm_container_registry.this.login_server}/novacart-backend:${var.backend_image_tag}"
      cpu    = var.container_cpu
      memory = var.container_memory
      env {
        name        = "DATABASE_URL"
        secret_name = "database-url"
      }
      env {
        name  = "APP_ENV"
        value = var.app_environment
      }
      env {
        name  = "API_VERSION"
        value = "v1"
      }
      env {
        name  = "LOG_LEVEL"
        value = "INFO"
      }
    }
  }

  ingress {
    external_enabled           = false
    target_port                = 8080
    transport                  = "http"
    allow_insecure_connections = true

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }

  depends_on = [
    azurerm_role_assignment.acr_pull,
    azurerm_postgresql_flexible_server_database.this
  ]
}

resource "azurerm_container_app" "frontend" {
  count                        = var.deploy_application ? 1 : 0
  name                         = "ca-${var.name_prefix}-frontend"
  container_app_environment_id = azurerm_container_app_environment.this.id
  resource_group_name          = azurerm_resource_group.this.name
  revision_mode                = "Single"
  tags                         = var.tags

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.container_apps.id]
  }

  registry {
    server   = azurerm_container_registry.this.login_server
    identity = azurerm_user_assigned_identity.container_apps.id
  }

  template {
    min_replicas = 1
    max_replicas = 2
    container {
      name   = "novacart-frontend"
      image  = "${azurerm_container_registry.this.login_server}/novacart-frontend:${var.frontend_image_tag}"
      cpu    = var.container_cpu
      memory = var.container_memory
      env {
        name  = "BACKEND_FQDN"
        value = azurerm_container_app.backend[0].ingress[0].fqdn
      }
      env {
        name  = "NGINX_ENVSUBST_FILTER"
        value = "^BACKEND_FQDN$"
      }
    }
  }

  ingress {
    external_enabled           = true
    target_port                = 80
    transport                  = "http"
    allow_insecure_connections = true

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }

  depends_on = [
    azurerm_role_assignment.acr_pull,
    azurerm_container_app.backend
  ]
}

# Restrict the public PostgreSQL firewall to the backend Container App's
# observed outbound IPs. In private mode, no public firewall rules are created.
resource "azurerm_postgresql_flexible_server_firewall_rule" "backend_egress" {
  for_each = var.deploy_application && !var.enable_private_database ? toset(azurerm_container_app.backend[0].outbound_ip_addresses) : toset([])

  name             = "aca-${substr(replace(each.value, ".", ""), 0, 15)}"
  server_id        = azurerm_postgresql_flexible_server.this.id
  start_ip_address = each.value
  end_ip_address   = each.value
}