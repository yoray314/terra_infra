resource "azurerm_virtual_network" "this" {
  name                = "vnet-${var.deployment_name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = var.virtual_network_address_space
  tags                = var.tags
}

resource "azurerm_subnet" "this" {
  name                 = var.subnet_name
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = var.subnet_address_prefixes

  lifecycle {
    precondition {
      condition = alltrue([
        for subnet_prefix in var.subnet_address_prefixes : anytrue([
          for network_prefix in var.virtual_network_address_space :
          cidrcontains(network_prefix, cidrhost(subnet_prefix, 0)) &&
          cidrcontains(network_prefix, cidrhost(subnet_prefix, -1))
        ])
      ])
      error_message = "Every subnet prefix must be contained in the virtual network address space."
    }
  }
}

resource "azurerm_public_ip" "this" {
  name                = "pip-${var.deployment_name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  domain_name_label   = var.dns_label
  tags                = var.tags
}

resource "azurerm_network_security_group" "this" {
  name                = "nsg-${var.deployment_name}"
  location            = var.location
  resource_group_name = var.resource_group_name
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
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.this.name
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
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.this.name
}

resource "azurerm_network_interface" "this" {
  name                = "nic-${var.deployment_name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  ip_configuration {
    name                          = "primary"
    subnet_id                     = azurerm_subnet.this.id
    private_ip_address_allocation = "Static"
    private_ip_address            = var.private_ip_address
    public_ip_address_id          = azurerm_public_ip.this.id
  }

  lifecycle {
    precondition {
      condition = anytrue([
        for subnet_prefix in var.subnet_address_prefixes :
        cidrcontains(subnet_prefix, var.private_ip_address)
      ])
      error_message = "The private IP address must be contained in an OpenBao subnet prefix."
    }
  }
}

resource "azurerm_network_interface_security_group_association" "this" {
  network_interface_id      = azurerm_network_interface.this.id
  network_security_group_id = azurerm_network_security_group.this.id
}

resource "azurerm_linux_virtual_machine" "this" {
  name                            = "vm-${var.deployment_name}"
  computer_name                   = var.computer_name
  location                        = var.location
  resource_group_name             = var.resource_group_name
  size                            = var.vm_size
  admin_username                  = var.admin_username
  disable_password_authentication = true
  disk_controller_type            = "SCSI"
  secure_boot_enabled             = true
  vtpm_enabled                    = true
  network_interface_ids           = [azurerm_network_interface.this.id]

  custom_data = base64encode(templatefile("${path.module}/cloud-init.yaml.tftpl", {
    caller_ipv4_cidr        = var.caller_ipv4_cidr
    fqdn                    = azurerm_public_ip.this.fqdn
    host_name               = var.computer_name
    node_id                 = var.node_id
    openbao_gpg_fingerprint = var.openbao_gpg_fingerprint
    openbao_version         = var.openbao_version
    private_ip              = var.private_ip_address
  }))

  dynamic "identity" {
    for_each = var.system_assigned_identity_enabled ? [true] : []

    content {
      type = "SystemAssigned"
    }
  }

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key
  }

  os_disk {
    name                 = var.os_disk_name
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

  depends_on = [azurerm_network_interface_security_group_association.this]
}

resource "azurerm_managed_disk" "raft" {
  name                 = var.raft_disk_name
  location             = var.location
  resource_group_name  = var.resource_group_name
  storage_account_type = "StandardSSD_LRS"
  create_option        = "Empty"
  disk_size_gb         = 32
  tags                 = var.tags
}

resource "azurerm_virtual_machine_data_disk_attachment" "raft" {
  managed_disk_id    = azurerm_managed_disk.raft.id
  virtual_machine_id = azurerm_linux_virtual_machine.this.id
  lun                = 0
  caching            = "None"
}
