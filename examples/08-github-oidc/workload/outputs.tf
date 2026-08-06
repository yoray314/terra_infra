output "virtual_network_id" {
  description = "Azure resource ID of the CI-managed virtual network."
  value       = azurerm_virtual_network.ci.id
}

output "virtual_network_name" {
  description = "Name of the CI-managed virtual network."
  value       = azurerm_virtual_network.ci.name
}
