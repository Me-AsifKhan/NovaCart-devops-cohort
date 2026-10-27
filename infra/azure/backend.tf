terraform {
  # Supply backend settings during CI init with -backend-config; do not hard-code account IDs here.
  backend "azurerm" {}
}