resource "azurerm_resource_group" "workload" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}
