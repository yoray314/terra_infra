output "resource_group_name" {
  description = "Name of the consumer resource group."
  value       = azurerm_resource_group.consumer.name
}

output "consumer_virtual_machine_name" {
  description = "Name of the private consumer VM."
  value       = azurerm_linux_virtual_machine.consumer.name
}

output "consumer_identity_client_id" {
  description = "Client ID of the consumer's user-assigned managed identity."
  value       = azurerm_user_assigned_identity.consumer.client_id
}

output "consumer_identity_principal_id" {
  description = "Principal ID receiving Key Vault read access."
  value       = azurerm_user_assigned_identity.consumer.principal_id
}

output "outbound_public_ip" {
  description = "Stable consumer egress address to add to the Key Vault firewall."
  value       = azurerm_public_ip.outbound.ip_address
}

output "outbound_public_ip_cidr" {
  description = "Stable consumer egress address in Key Vault firewall notation."
  value       = "${azurerm_public_ip.outbound.ip_address}/32"
}

output "key_vault_name" {
  description = "Name of the existing Key Vault used by the consumer."
  value       = data.azurerm_key_vault.secrets.name
}

output "key_vault_secret_name" {
  description = "Name of the Key Vault value read directly by the consumer."
  value       = var.key_vault_secret_name
}

output "openbao_resource_group_name" {
  description = "Resource group containing the OpenBao VM."
  value       = var.openbao_resource_group_name
}

output "openbao_role_id_secret_name" {
  description = "Key Vault secret name used for the OpenBao AppRole role ID."
  value       = var.openbao_role_id_secret_name
}

output "openbao_secret_id_secret_name" {
  description = "Key Vault secret name used for the OpenBao AppRole SecretID."
  value       = var.openbao_secret_id_secret_name
}

output "openbao_ca_secret_name" {
  description = "Key Vault secret name used for the public OpenBao CA."
  value       = var.openbao_ca_secret_name
}

output "openbao_workload_mount" {
  description = "OpenBao KV v2 mount read by the consumer."
  value       = var.openbao_workload_mount
}

output "openbao_workload_path" {
  description = "OpenBao KV v2 path read by the consumer."
  value       = var.openbao_workload_path
}
