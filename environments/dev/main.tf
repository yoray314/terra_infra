locals {
  tags = merge(var.tags, {
    environment  = "dev"
    example      = "09-modules-environments"
    "managed-by" = "opentofu"
    state        = "azure-blob"
  })
}

resource "azurerm_resource_group" "this" {
  name     = var.resource_group_name
  location = var.location
  tags     = local.tags
}

module "openbao" {
  source = "../../modules/openbao-lab"

  resource_group_name           = azurerm_resource_group.this.name
  location                      = azurerm_resource_group.this.location
  deployment_name               = "openbao-dev"
  computer_name                 = "openbao-dev"
  node_id                       = "openbao-dev-1"
  subnet_name                   = "snet-openbao-dev"
  os_disk_name                  = "disk-openbao-dev-os"
  raft_disk_name                = "disk-openbao-dev-raft"
  virtual_network_address_space = ["10.50.0.0/16"]
  subnet_address_prefixes       = ["10.50.1.0/24"]
  private_ip_address            = "10.50.1.10"
  caller_ipv4_cidr              = var.caller_ipv4_cidr
  dns_label                     = var.dns_label
  admin_username                = var.admin_username
  ssh_public_key                = file(pathexpand(var.ssh_public_key_path))
  vm_size                       = var.vm_size
  image_version                 = var.image_version
  openbao_version               = var.openbao_version
  openbao_gpg_fingerprint       = var.openbao_gpg_fingerprint
  tags                          = local.tags
}
