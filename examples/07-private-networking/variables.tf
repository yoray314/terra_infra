variable "resource_group_name" {
  description = "Name of the resource group containing private DNS and endpoint resources."
  type        = string
  nullable    = false

  validation {
    condition = (
      length(trimspace(var.resource_group_name)) > 0 &&
      length(var.resource_group_name) <= 90
    )
    error_message = "The resource group name must contain between 1 and 90 characters."
  }
}

variable "key_vault_name" {
  description = "Name of the existing Example 03 Key Vault."
  type        = string
  nullable    = false

  validation {
    condition = (
      can(regex("^[A-Za-z][A-Za-z0-9-]{1,22}[A-Za-z0-9]$", var.key_vault_name)) &&
      !strcontains(var.key_vault_name, "--")
    )
    error_message = "The Key Vault name must be a valid 3 to 24 character vault name."
  }
}

variable "key_vault_resource_group_name" {
  description = "Resource group containing the existing Key Vault."
  type        = string
  default     = "rg-opentofu-key-vault"
  nullable    = false
}

variable "openbao_resource_group_name" {
  description = "Resource group containing the OpenBao network."
  type        = string
  default     = "rg-opentofu-openbao"
  nullable    = false
}

variable "virtual_network_name" {
  description = "Name of the existing lab virtual network."
  type        = string
  default     = "vnet-openbao-lab"
  nullable    = false
}

variable "openbao_network_security_group_name" {
  description = "Name of the OpenBao VM network security group."
  type        = string
  default     = "nsg-openbao-lab"
  nullable    = false
}

variable "tags" {
  description = "Tags assigned to the private-networking resources."
  type        = map(string)
  default = {
    environment  = "learning"
    example      = "07-private-networking"
    "managed-by" = "opentofu"
    state        = "azure-blob"
  }
}
