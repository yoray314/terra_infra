data "azurerm_virtual_network" "lab" {
  name                = var.virtual_network_name
  resource_group_name = var.openbao_resource_group_name
}

data "azurerm_network_security_group" "openbao" {
  name                = var.openbao_network_security_group_name
  resource_group_name = var.openbao_resource_group_name
}

data "azurerm_key_vault" "secrets" {
  name                = var.key_vault_name
  resource_group_name = var.key_vault_resource_group_name
}

resource "azurerm_resource_group" "private_networking" {
  name     = var.resource_group_name
  location = data.azurerm_virtual_network.lab.location
  tags     = var.tags
}

resource "azurerm_subnet" "private_endpoints" {
  name                 = "snet-private-endpoints"
  resource_group_name  = data.azurerm_virtual_network.lab.resource_group_name
  virtual_network_name = data.azurerm_virtual_network.lab.name
  address_prefixes     = ["10.42.3.0/24"]

  default_outbound_access_enabled   = false
  private_endpoint_network_policies = "Disabled"
}

resource "azurerm_private_dns_zone" "key_vault" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = azurerm_resource_group.private_networking.name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "key_vault" {
  name                 = "link-key-vault-lab-vnet"
  private_dns_zone_id  = azurerm_private_dns_zone.key_vault.id
  virtual_network_id   = data.azurerm_virtual_network.lab.id
  registration_enabled = false
  tags                 = var.tags
}

resource "azurerm_private_endpoint" "key_vault" {
  name                = "pe-key-vault-lab"
  location            = azurerm_resource_group.private_networking.location
  resource_group_name = azurerm_resource_group.private_networking.name
  subnet_id           = azurerm_subnet.private_endpoints.id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-key-vault-lab"
    private_connection_resource_id = data.azurerm_key_vault.secrets.id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "key-vault"
    private_dns_zone_ids = [azurerm_private_dns_zone.key_vault.id]
  }
}

resource "azurerm_network_security_rule" "deny_internet_openbao_api" {
  name                        = "DenyInternetOpenBaoApi"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "8200"
  source_address_prefix       = "Internet"
  destination_address_prefix  = "*"
  resource_group_name         = data.azurerm_network_security_group.openbao.resource_group_name
  network_security_group_name = data.azurerm_network_security_group.openbao.name
}
