# Frontend and backend application runtimes for DEVOPS-009.
# The frontend is public; the backend uses internal ingress.

resource "azurerm_container_app" "backend" {
  count                        = var.deploy_application ? 1 : 0
  name                         = "ca-${var.name_prefix}-backend"
  container_app_environment_id = azurerm_container_app_environment.this.id
  resource_group_name          = azurerm_resource_group.this.name
  revision_mode                = "Multiple"
  max_inactive_revisions       = 10
  workload_profile_name        = "Consumption"
  tags                         = var.tags

  # Multiple revisions allow a candidate to be validated before traffic cutover.
  # The delivery workflow owns image rollouts by digest after bootstrap.
  lifecycle {
    # Terraform owns baseline app config; the release workflow owns revision images/suffixes and traffic weights.
    ignore_changes = [
      template[0].container[0].image,
      template[0].revision_suffix,
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
    # The pinned bootstrap revision receives traffic until a candidate passes readiness checks.
    revision_suffix = "bootstrap"
    # Keep one warm backend replica; cap the DEV ceiling until database load is measured.
    min_replicas = var.backend_min_replicas
    max_replicas = var.backend_max_replicas
    http_scale_rule {
      name                = "http-concurrency"
      concurrent_requests = tostring(var.backend_http_concurrency_target)
    }
    container {
      name   = "novacart-backend"
      image  = "${azurerm_container_registry.this.login_server}/novacart-backend:${var.backend_image_tag}"
      cpu    = var.container_cpu
      memory = var.container_memory

      startup_probe {
        transport               = "HTTP"
        path                    = "/health"
        port                    = 8080
        initial_delay           = 5
        interval_seconds        = 5
        timeout                 = 3
        failure_count_threshold = 24
      }

      readiness_probe {
        transport               = "HTTP"
        path                    = "/ready"
        port                    = 8080
        initial_delay           = 5
        interval_seconds        = 10
        timeout                 = 3
        failure_count_threshold = 3
        success_count_threshold = 1
      }

      liveness_probe {
        transport               = "HTTP"
        path                    = "/health"
        port                    = 8080
        initial_delay           = 10
        interval_seconds        = 10
        timeout                 = 3
        failure_count_threshold = 3
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
      env {
        name  = "DATABASE_POOL_MAX_SIZE"
        value = tostring(var.database_pool_max_size)
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
      revision_suffix = "bootstrap"
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
  max_inactive_revisions       = 10
  workload_profile_name        = "Consumption"
  tags                         = var.tags

  # After bootstrap, the delivery workflow owns image rollouts by digest.
  lifecycle {
    # Terraform owns baseline app config; the release workflow owns revision images/suffixes and traffic weights.
    ignore_changes = [
      template[0].container[0].image,
      template[0].revision_suffix,
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
    revision_suffix = "bootstrap"
    # The frontend is stateless; scale by HTTP concurrency with a bounded DEV maximum.
    min_replicas = var.frontend_min_replicas
    max_replicas = var.frontend_max_replicas
    http_scale_rule {
      name                = "http-concurrency"
      concurrent_requests = tostring(var.frontend_http_concurrency_target)
    }
    container {
      name   = "novacart-frontend"
      image  = "${azurerm_container_registry.this.login_server}/novacart-frontend:${var.frontend_image_tag}"
      cpu    = var.container_cpu
      memory = var.container_memory

      startup_probe {
        transport               = "HTTP"
        path                    = "/"
        port                    = 80
        initial_delay           = 2
        interval_seconds        = 5
        timeout                 = 3
        failure_count_threshold = 12
      }

      readiness_probe {
        transport               = "HTTP"
        path                    = "/"
        port                    = 80
        initial_delay           = 2
        interval_seconds        = 10
        timeout                 = 3
        failure_count_threshold = 3
        success_count_threshold = 1
      }

      liveness_probe {
        transport               = "HTTP"
        path                    = "/"
        port                    = 80
        initial_delay           = 10
        interval_seconds        = 10
        timeout                 = 3
        failure_count_threshold = 3
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
      revision_suffix = "bootstrap"
    }
  }

  depends_on = [
    azurerm_role_assignment.acr_pull,
    azurerm_container_app.backend
  ]
}
