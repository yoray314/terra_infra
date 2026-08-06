data "azurerm_virtual_network" "openbao" {
  name                = var.openbao_virtual_network_name
  resource_group_name = var.openbao_resource_group_name
}

data "azurerm_network_security_group" "openbao" {
  name                = "nsg-openbao-lab"
  resource_group_name = var.openbao_resource_group_name
}

data "azurerm_key_vault" "secrets" {
  name                = var.key_vault_name
  resource_group_name = var.key_vault_resource_group_name
}

resource "azurerm_resource_group" "consumer" {
  name     = var.resource_group_name
  location = data.azurerm_virtual_network.openbao.location
  tags     = var.tags
}

resource "azurerm_subnet" "consumer" {
  name                 = "snet-secret-consumer"
  resource_group_name  = data.azurerm_virtual_network.openbao.resource_group_name
  virtual_network_name = data.azurerm_virtual_network.openbao.name
  address_prefixes     = ["10.42.2.0/24"]

  default_outbound_access_enabled = false
}

resource "azurerm_network_security_rule" "openbao_consumer" {
  name                        = "AllowConsumerSubnet"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "8200"
  source_address_prefix       = azurerm_subnet.consumer.address_prefixes[0]
  destination_address_prefix  = "*"
  resource_group_name         = data.azurerm_network_security_group.openbao.resource_group_name
  network_security_group_name = data.azurerm_network_security_group.openbao.name
}

resource "azurerm_public_ip" "outbound" {
  name                = "pip-secret-consumer-outbound"
  location            = azurerm_resource_group.consumer.location
  resource_group_name = azurerm_resource_group.consumer.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_nat_gateway" "consumer" {
  name                    = "nat-secret-consumer"
  location                = azurerm_resource_group.consumer.location
  resource_group_name     = azurerm_resource_group.consumer.name
  sku_name                = "Standard"
  idle_timeout_in_minutes = 10
  tags                    = var.tags
}

resource "azurerm_nat_gateway_public_ip_association" "consumer" {
  nat_gateway_id       = azurerm_nat_gateway.consumer.id
  public_ip_address_id = azurerm_public_ip.outbound.id
}

resource "azurerm_subnet_nat_gateway_association" "consumer" {
  subnet_id      = azurerm_subnet.consumer.id
  nat_gateway_id = azurerm_nat_gateway.consumer.id
}

resource "azurerm_user_assigned_identity" "consumer" {
  name                = "id-secret-consumer"
  location            = azurerm_resource_group.consumer.location
  resource_group_name = azurerm_resource_group.consumer.name
  tags                = var.tags
}

resource "azurerm_role_assignment" "key_vault_secrets_user" {
  scope                = data.azurerm_key_vault.secrets.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.consumer.principal_id
  principal_type       = "ServicePrincipal"
  description          = "Allow the lab consumer identity to read Key Vault secrets."
}

resource "azurerm_network_security_group" "consumer" {
  name                = "nsg-secret-consumer"
  location            = azurerm_resource_group.consumer.location
  resource_group_name = azurerm_resource_group.consumer.name
  tags                = var.tags

  security_rule {
    name                       = "DenyAllInbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface" "consumer" {
  name                = "nic-secret-consumer"
  location            = azurerm_resource_group.consumer.location
  resource_group_name = azurerm_resource_group.consumer.name
  tags                = var.tags

  ip_configuration {
    name                          = "primary"
    subnet_id                     = azurerm_subnet.consumer.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.42.2.10"
  }
}

resource "azurerm_network_interface_security_group_association" "consumer" {
  network_interface_id      = azurerm_network_interface.consumer.id
  network_security_group_id = azurerm_network_security_group.consumer.id
}

resource "azurerm_linux_virtual_machine" "consumer" {
  name                            = "vm-secret-consumer"
  computer_name                   = "secret-consumer"
  location                        = azurerm_resource_group.consumer.location
  resource_group_name             = azurerm_resource_group.consumer.name
  size                            = var.vm_size
  admin_username                  = var.admin_username
  disable_password_authentication = true
  disk_controller_type            = "SCSI"
  secure_boot_enabled             = true
  vtpm_enabled                    = true
  network_interface_ids           = [azurerm_network_interface.consumer.id]

  custom_data = base64encode(templatefile("${path.module}/cloud-init.yaml.tftpl", {
    identity_client_id       = azurerm_user_assigned_identity.consumer.client_id
    key_vault_name           = data.azurerm_key_vault.secrets.name
    key_vault_secret_name    = var.key_vault_secret_name
    openbao_address          = var.openbao_private_address
    openbao_ca_secret_name   = var.openbao_ca_secret_name
    openbao_role_id_secret   = var.openbao_role_id_secret_name
    openbao_secret_id_secret = var.openbao_secret_id_secret_name
    openbao_workload_mount   = var.openbao_workload_mount
    openbao_workload_path    = var.openbao_workload_path
  }))

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.consumer.id]
  }

  admin_ssh_key {
    username   = var.admin_username
    public_key = file(pathexpand(var.ssh_public_key_path))
  }

  os_disk {
    name                 = "disk-secret-consumer-os"
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
    disk_size_gb         = 30
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = var.image_version
  }

  boot_diagnostics {}

  tags = var.tags

  depends_on = [
    azurerm_network_interface_security_group_association.consumer,
    azurerm_nat_gateway_public_ip_association.consumer,
    azurerm_subnet_nat_gateway_association.consumer,
  ]
}
