resource "azurerm_resource_group" "openbao" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

module "openbao" {
  source = "../../modules/openbao-lab"

  resource_group_name              = azurerm_resource_group.openbao.name
  location                         = azurerm_resource_group.openbao.location
  deployment_name                  = "openbao-lab"
  computer_name                    = "openbao-lab"
  node_id                          = "openbao-1"
  subnet_name                      = "snet-openbao"
  os_disk_name                     = "disk-openbao-os"
  raft_disk_name                   = "disk-openbao-raft"
  virtual_network_address_space    = ["10.42.0.0/16"]
  subnet_address_prefixes          = ["10.42.1.0/24"]
  private_ip_address               = "10.42.1.10"
  caller_ipv4_cidr                 = var.caller_ipv4_cidr
  dns_label                        = var.dns_label
  admin_username                   = var.admin_username
  ssh_public_key                   = file(pathexpand(var.ssh_public_key_path))
  system_assigned_identity_enabled = true
  vm_size                          = var.vm_size
  image_version                    = var.image_version
  openbao_version                  = var.openbao_version
  openbao_gpg_fingerprint          = var.openbao_gpg_fingerprint
  tags                             = var.tags
}
