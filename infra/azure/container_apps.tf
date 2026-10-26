# Frontend and backend application runtimes for DEVOPS-009.
# The frontend is public; the backend uses internal ingress.

resource "azurerm_container_app" "backend" {
  count                        = var.deploy_application ? 1 : 0
  name                         = "ca-${var.name_prefix}-backend"
  container_app_environment_id = azurerm_container_app_environment.this.id
  resource_group_name          = azurerm_resource_group.this.name
  revision_mode                = "Single"
  workload_profile_name         = "Consumption"
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
    # Keep one backend replica available for development verification.
    min_replicas = 1
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
  workload_profile_name         = "Consumption"
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
