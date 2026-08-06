mock_provider "azurerm" {
  mock_resource "azurerm_subnet" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-openbao-unit/providers/Microsoft.Network/virtualNetworks/vnet-openbao-unit/subnets/snet-openbao-unit"
    }
  }

  mock_resource "azurerm_public_ip" {
    defaults = {
      fqdn       = "openbao-unit-314159.eastus.cloudapp.azure.com"
      id         = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-openbao-unit/providers/Microsoft.Network/publicIPAddresses/pip-openbao-unit"
      ip_address = "198.51.100.10"
    }
  }

  mock_resource "azurerm_network_security_group" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-openbao-unit/providers/Microsoft.Network/networkSecurityGroups/nsg-openbao-unit"
    }
  }

  mock_resource "azurerm_network_interface" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-openbao-unit/providers/Microsoft.Network/networkInterfaces/nic-openbao-unit"
    }
  }

  mock_resource "azurerm_linux_virtual_machine" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-openbao-unit/providers/Microsoft.Compute/virtualMachines/vm-openbao-unit"
    }
  }

  mock_resource "azurerm_managed_disk" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-openbao-unit/providers/Microsoft.Compute/disks/disk-openbao-unit-raft"
    }
  }
}

variables {
  resource_group_name              = "rg-openbao-unit"
  location                         = "eastus"
  deployment_name                  = "openbao-unit"
  computer_name                    = "openbao-unit"
  node_id                          = "openbao-unit-1"
  subnet_name                      = "snet-openbao-unit"
  os_disk_name                     = "disk-openbao-unit-os"
  raft_disk_name                   = "disk-openbao-unit-raft"
  virtual_network_address_space    = ["10.60.0.0/16"]
  subnet_address_prefixes          = ["10.60.1.0/24"]
  private_ip_address               = "10.60.1.10"
  caller_ipv4_cidr                 = "198.51.100.20/32"
  dns_label                        = "openbao-unit-314159"
  admin_username                   = "azureadmin"
  ssh_public_key                   = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOm+MMeUavzWIFQcyQkxZMxaJeW+XzVBD8K1Qbw3rxjd openbao-test"
  system_assigned_identity_enabled = true
  vm_size                          = "Standard_B2s_v2"
  image_version                    = "24.04.202608020"
  openbao_version                  = "2.6.1"
  openbao_gpg_fingerprint          = "66D15FDD87287219C8E15478D200CD702853E6D0"
  tags = {
    environment = "unit"
  }
}

run "secure_openbao_plan" {
  command = plan

  plan_options {
    refresh = false
  }

  assert {
    condition     = azurerm_virtual_network.this.name == "vnet-openbao-unit"
    error_message = "The deployment name was not applied to the virtual network."
  }

  assert {
    condition = (
      azurerm_network_security_rule.operator.source_address_prefix == "198.51.100.20/32" &&
      toset(azurerm_network_security_rule.operator.destination_port_ranges) == toset(["22", "8200"]) &&
      azurerm_network_security_rule.operator.direction == "Inbound" &&
      azurerm_network_security_rule.operator.access == "Allow" &&
      azurerm_network_security_rule.operator.protocol == "Tcp" &&
      azurerm_network_security_rule.operator.priority == 120 &&
      azurerm_network_security_rule.operator.priority < azurerm_network_security_rule.deny_all_inbound.priority &&
      azurerm_network_security_rule.operator.source_port_range == "*" &&
      azurerm_network_security_rule.operator.destination_address_prefix == "*" &&
      azurerm_network_security_rule.operator.network_security_group_name == azurerm_network_security_group.this.name
    )
    error_message = "Operator access must remain restricted to the declared /32 and administration ports."
  }

  assert {
    condition = (
      azurerm_network_security_rule.deny_all_inbound.access == "Deny" &&
      azurerm_network_security_rule.deny_all_inbound.priority == 4096 &&
      azurerm_network_security_rule.deny_all_inbound.direction == "Inbound" &&
      azurerm_network_security_rule.deny_all_inbound.protocol == "*" &&
      azurerm_network_security_rule.deny_all_inbound.source_port_range == "*" &&
      azurerm_network_security_rule.deny_all_inbound.destination_port_range == "*" &&
      azurerm_network_security_rule.deny_all_inbound.source_address_prefix == "*" &&
      azurerm_network_security_rule.deny_all_inbound.destination_address_prefix == "*" &&
      azurerm_network_security_rule.deny_all_inbound.network_security_group_name == azurerm_network_security_group.this.name
    )
    error_message = "The terminal deny-all inbound rule is missing or has the wrong priority."
  }

  assert {
    condition = (
      azurerm_network_interface_security_group_association.this.network_interface_id == azurerm_network_interface.this.id &&
      azurerm_network_interface_security_group_association.this.network_security_group_id == azurerm_network_security_group.this.id &&
      toset(azurerm_linux_virtual_machine.this.network_interface_ids) == toset([azurerm_network_interface.this.id])
    )
    error_message = "The OpenBao network security group must remain attached to the VM network interface."
  }

  assert {
    condition = (
      azurerm_public_ip.this.allocation_method == "Static" &&
      azurerm_public_ip.this.sku == "Standard" &&
      azurerm_public_ip.this.domain_name_label == "openbao-unit-314159" &&
      azurerm_network_interface.this.ip_configuration[0].private_ip_address_allocation == "Static" &&
      azurerm_network_interface.this.ip_configuration[0].private_ip_address == "10.60.1.10"
    )
    error_message = "The public and private IP configuration changed unexpectedly."
  }

  assert {
    condition = (
      azurerm_linux_virtual_machine.this.disable_password_authentication &&
      azurerm_linux_virtual_machine.this.secure_boot_enabled &&
      azurerm_linux_virtual_machine.this.vtpm_enabled &&
      azurerm_linux_virtual_machine.this.identity[0].type == "SystemAssigned"
    )
    error_message = "The VM must disable passwords, retain Trusted Launch, and expose a system identity."
  }

  assert {
    condition = (
      azurerm_linux_virtual_machine.this.os_disk[0].storage_account_type == "StandardSSD_LRS" &&
      azurerm_managed_disk.raft.storage_account_type == "StandardSSD_LRS" &&
      azurerm_virtual_machine_data_disk_attachment.raft.caching == "None" &&
      azurerm_virtual_machine_data_disk_attachment.raft.lun == 0 &&
      azurerm_linux_virtual_machine.this.disk_controller_type == "SCSI"
    )
    error_message = "The operating-system and Raft disk contract changed unexpectedly."
  }

  assert {
    condition = (
      azurerm_linux_virtual_machine.this.source_image_reference[0].publisher == "Canonical" &&
      azurerm_linux_virtual_machine.this.source_image_reference[0].offer == "ubuntu-24_04-lts" &&
      azurerm_linux_virtual_machine.this.source_image_reference[0].sku == "server" &&
      azurerm_linux_virtual_machine.this.source_image_reference[0].version == "24.04.202608020"
    )
    error_message = "The VM must retain the pinned Ubuntu image contract."
  }

  assert {
    condition = (
      strcontains(base64decode(azurerm_linux_virtual_machine.this.custom_data), "OPENBAO_VERSION='2.6.1'") &&
      strcontains(base64decode(azurerm_linux_virtual_machine.this.custom_data), "OPENBAO_GPG_FINGERPRINT='66D15FDD87287219C8E15478D200CD702853E6D0'") &&
      strcontains(base64decode(azurerm_linux_virtual_machine.this.custom_data), "CALLER_CIDR='198.51.100.20/32'") &&
      strcontains(base64decode(azurerm_linux_virtual_machine.this.custom_data), "node_id = \"openbao-unit-1\"")
    )
    error_message = "Cloud-init must receive the pinned package trust, operator CIDR, and stable node ID."
  }

  assert {
    condition     = output.url == "https://openbao-unit-314159.eastus.cloudapp.azure.com:8200"
    error_message = "The module URL output does not use the public IP FQDN."
  }
}

run "reject_private_operator_cidr" {
  command = plan

  plan_options {
    refresh = false
  }

  variables {
    caller_ipv4_cidr = "10.0.0.10/32"
  }

  expect_failures = [var.caller_ipv4_cidr]
}

run "reject_unsafe_node_id" {
  command = plan

  plan_options {
    refresh = false
  }

  variables {
    node_id = "$(touch-pwned)"
  }

  expect_failures = [var.node_id]
}

run "reject_invalid_ssh_key" {
  command = plan

  plan_options {
    refresh = false
  }

  variables {
    ssh_public_key = "not-a-public-key"
  }

  expect_failures = [var.ssh_public_key]
}

run "reject_mixed_subnets" {
  command = plan

  plan_options {
    refresh = false
  }

  variables {
    subnet_address_prefixes = ["10.60.1.0/24", "10.61.1.0/24"]
  }

  expect_failures = [azurerm_subnet.this]
}

run "reject_subnet_extending_outside_network" {
  command = plan

  plan_options {
    refresh = false
  }

  variables {
    subnet_address_prefixes = ["10.60.0.0/15"]
  }

  expect_failures = [azurerm_subnet.this]
}

run "reject_private_ip_outside_subnet" {
  command = plan

  plan_options {
    refresh = false
  }

  variables {
    private_ip_address = "10.60.2.10"
  }

  expect_failures = [azurerm_network_interface.this]
}
