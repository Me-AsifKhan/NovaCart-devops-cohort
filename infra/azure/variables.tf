variable "subscription_id" {
  description = "Azure subscription ID. Supply through TF_VAR_subscription_id."
  type        = string
  sensitive   = true
}

variable "location" {
  description = "Azure region for development resources."
  type        = string
  default     = "centralindia"
}

variable "name_prefix" {
  description = "Short name prefix for NovaCart development resources."
  type        = string
  default     = "novacart-dev"
}

variable "acr_name" {
  description = "Globally unique ACR name containing only letters and numbers."
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9]{5,50}$", var.acr_name))
    error_message = "acr_name must contain 5-50 alphanumeric characters."
  }
}

variable "postgres_server_name" {
  description = "Globally unique lowercase PostgreSQL server name."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]{1,61}[a-z0-9])$", var.postgres_server_name))
    error_message = "Use 3-63 lowercase letters, numbers, or hyphens."
  }
}

variable "db_admin_username" {
  description = "Administrator username for the development database server."
  type        = string
  default     = "novacartadmin"
}

variable "db_admin_password" {
  description = "Development PostgreSQL administrator password; supply securely through TF_VAR_db_admin_password."
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.db_admin_password) >= 16
    error_message = "Use a unique password with at least 16 characters."
  }
}

variable "database_name" {
  description = "Name of the NovaCart development database."
  type        = string
  default     = "novacart"
}

variable "dev_client_ip" {
  description = "Optional single public IPv4 address permitted to connect to PostgreSQL. Leave null until approved."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition     = var.dev_client_ip == null || (can(regex("^[0-9]{1,3}[.][0-9]{1,3}[.][0-9]{1,3}[.][0-9]{1,3}$", var.dev_client_ip)) && can(cidrhost("${var.dev_client_ip}/32", 0)))
    error_message = "dev_client_ip must be a valid IPv4 address or null."
  }
}

variable "postgres_sku_name" {
  description = "PostgreSQL Flexible Server compute SKU; confirm regional availability and current price before deployment."
  type        = string
  default     = "B_Standard_B1ms"
}

variable "postgres_storage_mb" {
  description = "PostgreSQL storage size in MB."
  type        = number
  default     = 32768
}

variable "log_retention_days" {
  description = "Log Analytics retention in days."
  type        = number
  default     = 30

  validation {
    condition     = var.log_retention_days >= 30 && var.log_retention_days <= 730
    error_message = "Retention must be between 30 and 730 days."
  }
}

variable "tags" {
  description = "Common resource tags."
  type        = map(string)
  default = {
    application = "NovaCart"
    environment = "development"
    managed_by  = "Terraform"
    ticket      = "DEVOPS-008"
  }
}

variable "deploy_application" {
  description = "Deploy frontend and backend Container Apps after their images have been pushed to ACR."
  type        = bool
  default     = false
}

variable "enable_private_database" {
  description = "Use VNet-integrated Container Apps and private PostgreSQL networking (DEVOPS-011). Enabling this replaces networking resources and may replace PostgreSQL."
  type        = bool
  default     = false
}

variable "backend_image_tag" {
  description = "Existing backend image tag in ACR."
  type        = string
  default     = "devops-009"
}

variable "frontend_image_tag" {
  description = "Existing frontend image tag in ACR."
  type        = string
  default     = "devops-009-fix2"
}

variable "container_cpu" {
  description = "CPU allocation per app container in vCPU. Keep paired with a supported Azure Container Apps Consumption memory size."
  type        = number
  default     = 0.5
  validation {
    condition = (
      (var.container_cpu == 0.25 && var.container_memory == "0.5Gi") ||
      (var.container_cpu == 0.5 && var.container_memory == "1Gi") ||
      (var.container_cpu == 0.75 && var.container_memory == "1.5Gi") ||
      (var.container_cpu == 1.0 && var.container_memory == "2Gi") ||
      (var.container_cpu == 1.25 && var.container_memory == "2.5Gi") ||
      (var.container_cpu == 1.5 && var.container_memory == "3Gi") ||
      (var.container_cpu == 1.75 && var.container_memory == "3.5Gi") ||
      (var.container_cpu == 2.0 && var.container_memory == "4Gi")
    )
    error_message = "Use a supported Consumption CPU/memory pair: 0.25/0.5Gi, 0.5/1Gi, 0.75/1.5Gi, 1/2Gi, 1.25/2.5Gi, 1.5/3Gi, 1.75/3.5Gi, or 2/4Gi."
  }
}

variable "container_memory" {
  description = "Memory allocation per app container."
  type        = string
  default     = "1Gi"
}

variable "app_environment" {
  description = "Application environment name."
  type        = string
  default     = "development"
}

 
variable "backend_min_replicas" {
  description = "Minimum backend replicas per active revision. A value of 1 avoids scale-from-zero latency; costs more during a release while old and new revisions overlap."
  type        = number
  default     = 1

  validation {
    condition     = var.backend_min_replicas >= 0 && var.backend_min_replicas <= 10 && var.backend_min_replicas == floor(var.backend_min_replicas)
    error_message = "backend_min_replicas must be an integer between 0 and 10."
  }
}

variable "backend_max_replicas" {
  description = "Bounded DEV maximum for backend replicas; raise only after database connection capacity and load tests justify it."
  type        = number
  default     = 5

  validation {
    condition     = var.backend_max_replicas >= 1 && var.backend_max_replicas <= 10 && var.backend_max_replicas == floor(var.backend_max_replicas) && var.backend_max_replicas >= var.backend_min_replicas
    error_message = "backend_max_replicas must be an integer from backend_min_replicas through 10."
  }
}

variable "frontend_min_replicas" {
  description = "Minimum frontend replicas per active revision; one warm replica avoids cold-start latency and increases temporary blue/green release cost."
  type        = number
  default     = 1

  validation {
    condition     = var.frontend_min_replicas >= 0 && var.frontend_min_replicas <= 10 && var.frontend_min_replicas == floor(var.frontend_min_replicas)
    error_message = "frontend_min_replicas must be an integer between 0 and 10."
  }
}

variable "frontend_max_replicas" {
  description = "Bounded DEV maximum for stateless Nginx frontend replicas."
  type        = number
  default     = 10

  validation {
    condition     = var.frontend_max_replicas >= 1 && var.frontend_max_replicas <= 10 && var.frontend_max_replicas == floor(var.frontend_max_replicas) && var.frontend_max_replicas >= var.frontend_min_replicas
    error_message = "frontend_max_replicas must be an integer from frontend_min_replicas through 10."
  }
}

variable "backend_http_concurrency_target" {
  description = "HTTP concurrent-request target per backend replica. Initial starting point only; tune after load testing and PostgreSQL connection-capacity review."
  type        = number
  default     = 25

  validation {
    condition     = var.backend_http_concurrency_target >= 1 && var.backend_http_concurrency_target <= 1000
    error_message = "backend_http_concurrency_target must be between 1 and 1000."
  }
}

variable "frontend_http_concurrency_target" {
  description = "HTTP concurrent-request target per frontend replica. Initial starting point only; tune after load testing."
  type        = number
  default     = 50

  validation {
    condition     = var.frontend_http_concurrency_target >= 1 && var.frontend_http_concurrency_target <= 1000
    error_message = "frontend_http_concurrency_target must be between 1 and 1000."
  }
}
