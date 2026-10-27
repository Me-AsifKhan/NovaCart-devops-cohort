# Optional private networking resources used by DEVOPS-011.
# Keeping this in a separate file makes the network mode easier to review.

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
