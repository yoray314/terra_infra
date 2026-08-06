variable "resource_group_name" {
  description = "Name of the disposable resource group containing the Key Vault."
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
  description = "Globally unique name of the Azure Key Vault."
  type        = string
  nullable    = false

  validation {
    condition = (
      can(regex("^[A-Za-z][A-Za-z0-9-]{1,22}[A-Za-z0-9]$", var.key_vault_name)) &&
      !strcontains(var.key_vault_name, "--")
    )
    error_message = "The Key Vault name must be 3 to 24 alphanumeric or single-hyphen characters."
  }
}

variable "allowed_ipv4_cidrs" {
  description = "Public IPv4 /32 egress addresses allowed through the Key Vault firewall."
  type        = list(string)
  nullable    = false

  validation {
    condition = (
      length(var.allowed_ipv4_cidrs) > 0 &&
      alltrue([
        for cidr in var.allowed_ipv4_cidrs :
        can(cidrnetmask(cidr)) &&
        endswith(cidr, "/32") &&
        !strcontains(cidr, ":") &&
        !can(regex("^(10\\.|127\\.|169\\.254\\.|192\\.168\\.|172\\.(1[6-9]|2[0-9]|3[01])\\.)", cidr))
      ])
    )
    error_message = "Provide at least one valid public IPv4 address in /32 CIDR notation."
  }
}

variable "public_network_access_enabled" {
  description = "Whether the Key Vault data plane accepts traffic through its public endpoint."
  type        = bool
  default     = true
  nullable    = false
}

variable "location" {
  description = "Azure region used for the Key Vault resources."
  type        = string
  default     = "westeurope"
  nullable    = false

  validation {
    condition     = length(trimspace(var.location)) > 0
    error_message = "The Azure location must not be empty."
  }
}

variable "tags" {
  description = "Tags assigned to the Key Vault resource group and vault."
  type        = map(string)
  default = {
    environment  = "learning"
    example      = "03-key-vault"
    "managed-by" = "opentofu"
    state        = "azure-blob"
  }
}
