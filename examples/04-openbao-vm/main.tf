locals {
  private_ip = "10.42.1.10"
}

resource "azurerm_resource_group" "openbao" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

resource "azurerm_virtual_network" "openbao" {
  name                = "vnet-openbao-lab"
  location            = azurerm_resource_group.openbao.location
  resource_group_name = azurerm_resource_group.openbao.name
  address_space       = ["10.42.0.0/16"]
  tags                = var.tags
}

resource "azurerm_subnet" "openbao" {
  name                 = "snet-openbao"
  resource_group_name  = azurerm_resource_group.openbao.name
  virtual_network_name = azurerm_virtual_network.openbao.name
  address_prefixes     = ["10.42.1.0/24"]
}

resource "azurerm_public_ip" "openbao" {
  name                = "pip-openbao-lab"
  location            = azurerm_resource_group.openbao.location
  resource_group_name = azurerm_resource_group.openbao.name
  allocation_method   = "Static"
  sku                 = "Standard"
  domain_name_label   = var.dns_label
  tags                = var.tags
}

resource "azurerm_network_security_group" "openbao" {
  name                = "nsg-openbao-lab"
  location            = azurerm_resource_group.openbao.location
  resource_group_name = azurerm_resource_group.openbao.name
  tags                = var.tags
}

resource "azurerm_network_security_rule" "operator" {
  name                        = "AllowOperator"
  priority                    = 120
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = ["22", "8200"]
  source_address_prefix       = var.caller_ipv4_cidr
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.openbao.name
  network_security_group_name = azurerm_network_security_group.openbao.name
}

resource "azurerm_network_security_rule" "deny_all_inbound" {
  name                        = "DenyAllInbound"
  priority                    = 4096
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.openbao.name
  network_security_group_name = azurerm_network_security_group.openbao.name
}

resource "azurerm_network_interface" "openbao" {
  name                = "nic-openbao-lab"
  location            = azurerm_resource_group.openbao.location
  resource_group_name = azurerm_resource_group.openbao.name
  tags                = var.tags

  ip_configuration {
    name                          = "primary"
    subnet_id                     = azurerm_subnet.openbao.id
    private_ip_address_allocation = "Static"
    private_ip_address            = local.private_ip
    public_ip_address_id          = azurerm_public_ip.openbao.id
  }
}

resource "azurerm_network_interface_security_group_association" "openbao" {
  network_interface_id      = azurerm_network_interface.openbao.id
  network_security_group_id = azurerm_network_security_group.openbao.id
}

resource "azurerm_linux_virtual_machine" "openbao" {
  name                            = "vm-openbao-lab"
  computer_name                   = "openbao-lab"
  location                        = azurerm_resource_group.openbao.location
  resource_group_name             = azurerm_resource_group.openbao.name
  size                            = var.vm_size
  admin_username                  = var.admin_username
  disable_password_authentication = true
  disk_controller_type            = "SCSI"
  secure_boot_enabled             = true
  vtpm_enabled                    = true
  network_interface_ids           = [azurerm_network_interface.openbao.id]

  custom_data = base64encode(templatefile("${path.module}/cloud-init.yaml.tftpl", {
    caller_ipv4_cidr        = var.caller_ipv4_cidr
    fqdn                    = azurerm_public_ip.openbao.fqdn
    openbao_gpg_fingerprint = var.openbao_gpg_fingerprint
    openbao_version         = var.openbao_version
    private_ip              = local.private_ip
  }))

  admin_ssh_key {
    username   = var.admin_username
    public_key = file(pathexpand(var.ssh_public_key_path))
  }

  os_disk {
    name                 = "disk-openbao-os"
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
    disk_size_gb         = 32
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = var.image_version
  }

  boot_diagnostics {}

  tags = var.tags

  depends_on = [azurerm_network_interface_security_group_association.openbao]
}

resource "azurerm_managed_disk" "raft" {
  name                 = "disk-openbao-raft"
  location             = azurerm_resource_group.openbao.location
  resource_group_name  = azurerm_resource_group.openbao.name
  storage_account_type = "StandardSSD_LRS"
  create_option        = "Empty"
  disk_size_gb         = 32
  tags                 = var.tags
}

resource "azurerm_virtual_machine_data_disk_attachment" "raft" {
  managed_disk_id    = azurerm_managed_disk.raft.id
  virtual_machine_id = azurerm_linux_virtual_machine.openbao.id
  lun                = 0
  caching            = "None"
}
