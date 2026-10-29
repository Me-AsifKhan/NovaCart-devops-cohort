# Frontend and backend application runtimes for DEVOPS-009.
# The frontend is public; the backend uses internal ingress.

resource "azurerm_container_app" "backend" {
  count                        = var.deploy_application ? 1 : 0
  name                         = "ca-${var.name_prefix}-backend"
  container_app_environment_id = azurerm_container_app_environment.this.id
  resource_group_name          = azurerm_resource_group.this.name
  revision_mode                = "Multiple"
  workload_profile_name        = "Consumption"
  tags                         = var.tags

  # After bootstrap, the delivery workflow owns image rollouts by digest.
  # Release automation owns image rollouts and revision traffic after bootstrap.
  # Ignore only these fields so Terraform does not reset an approved canary/promotion.
  lifecycle {
    ignore_changes = [
      template[0].container[0].image,
      ingress[0].traffic_weight,
    ]
  }

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
    # Keep one replica ready; scale up to five while the database is the main shared bottleneck.
    # The HTTP threshold is a starting hypothesis and must be validated with a load test.
    min_replicas = var.container_min_replicas
    max_replicas = var.container_max_replicas

    http_scale_rule {
      name                = "http-concurrency"
      concurrent_requests = tostring(var.http_concurrent_requests)
    }

    container {
      name   = "novacart-backend"
      image  = "${azurerm_container_registry.this.login_server}/novacart-backend:${var.backend_image_tag}"
      cpu    = var.container_cpu
      memory = var.container_memory

      # Process-level health: do not restart the app just because PostgreSQL is unavailable.
      liveness_probe {
        transport                 = "HTTP"
        port                      = 8080
        path                      = "/health"
        interval_seconds          = 10
        timeout                   = 3
        failure_count_threshold   = 3
      }

      startup_probe {
        transport                 = "HTTP"
        port                      = 8080
        path                      = "/health"
        interval_seconds          = 5
        timeout                   = 3
        failure_count_threshold   = 24
      }

      # Readiness includes a database query; failed readiness removes this replica from traffic.
      readiness_probe {
        transport                 = "HTTP"
        port                      = 8080
        path                      = "/ready"
        interval_seconds          = 5
        timeout                   = 3
        failure_count_threshold   = 3
        success_count_threshold   = 1
      }

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
  revision_mode                = "Multiple"
  workload_profile_name        = "Consumption"
  tags                         = var.tags

  # After bootstrap, the delivery workflow owns image rollouts by digest.
  # Release automation owns image rollouts and revision traffic after bootstrap.
  # Ignore only these fields so Terraform does not reset an approved canary/promotion.
  lifecycle {
    ignore_changes = [
      template[0].container[0].image,
      ingress[0].traffic_weight,
    ]
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.container_apps.id]
  }

  registry {
    server   = azurerm_container_registry.this.login_server
    identity = azurerm_user_assigned_identity.container_apps.id
  }

  template {
    min_replicas = var.container_min_replicas
    max_replicas = var.container_max_replicas

    http_scale_rule {
      name                = "http-concurrency"
      concurrent_requests = tostring(var.http_concurrent_requests)
    }

    container {
      name   = "novacart-frontend"
      image  = "${azurerm_container_registry.this.login_server}/novacart-frontend:${var.frontend_image_tag}"
      cpu    = var.container_cpu
      memory = var.container_memory

      startup_probe {
        transport               = "HTTP"
        port                    = 80
        path                    = "/"
        interval_seconds        = 5
        timeout                 = 3
        failure_count_threshold = 12
      }

      liveness_probe {
        transport               = "HTTP"
        port                    = 80
        path                    = "/"
        interval_seconds        = 10
        timeout                 = 3
        failure_count_threshold = 3
      }

      readiness_probe {
        transport                 = "HTTP"
        port                      = 80
        path                      = "/"
        interval_seconds          = 5
        timeout                   = 3
        failure_count_threshold   = 3
        success_count_threshold   = 1
      }

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
