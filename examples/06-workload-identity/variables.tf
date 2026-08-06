variable "resource_group_name" {
  description = "Name of the resource group containing the consumer resources."
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
  description = "Resource group containing the existing Example 03 Key Vault."
  type        = string
  default     = "rg-opentofu-key-vault"
  nullable    = false
}

variable "openbao_resource_group_name" {
  description = "Resource group containing the Example 04 OpenBao virtual network."
  type        = string
  default     = "rg-opentofu-openbao"
  nullable    = false
}

variable "openbao_virtual_network_name" {
  description = "Name of the Example 04 OpenBao virtual network."
  type        = string
  default     = "vnet-openbao-lab"
  nullable    = false
}

variable "openbao_private_address" {
  description = "Private HTTPS address of the OpenBao API."
  type        = string
  default     = "https://10.42.1.10:8200"
  nullable    = false

  validation {
    condition     = var.openbao_private_address == "https://10.42.1.10:8200"
    error_message = "This lab expects the private OpenBao address https://10.42.1.10:8200."
  }
}

variable "key_vault_secret_name" {
  description = "Key Vault secret read directly by the consumer."
  type        = string
  default     = "consumer-key-vault-value"
  nullable    = false

  validation {
    condition     = can(regex("^[A-Za-z0-9-]{1,127}$", var.key_vault_secret_name))
    error_message = "The Key Vault secret name contains unsupported characters."
  }
}

variable "openbao_role_id_secret_name" {
  description = "Key Vault secret containing the OpenBao AppRole role ID."
  type        = string
  default     = "openbao-consumer-role-id"
  nullable    = false

  validation {
    condition     = can(regex("^[A-Za-z0-9-]{1,127}$", var.openbao_role_id_secret_name))
    error_message = "The role-ID secret name contains unsupported characters."
  }
}

variable "openbao_secret_id_secret_name" {
  description = "Key Vault secret containing the OpenBao AppRole secret ID."
  type        = string
  default     = "openbao-consumer-secret-id"
  nullable    = false

  validation {
    condition     = can(regex("^[A-Za-z0-9-]{1,127}$", var.openbao_secret_id_secret_name))
    error_message = "The SecretID secret name contains unsupported characters."
  }
}

variable "openbao_ca_secret_name" {
  description = "Key Vault secret containing the public OpenBao lab CA certificate."
  type        = string
  default     = "openbao-lab-ca-pem"
  nullable    = false

  validation {
    condition     = can(regex("^[A-Za-z0-9-]{1,127}$", var.openbao_ca_secret_name))
    error_message = "The CA secret name contains unsupported characters."
  }
}

variable "openbao_workload_mount" {
  description = "OpenBao KV v2 mount read by the consumer."
  type        = string
  default     = "lab"
  nullable    = false

  validation {
    condition     = can(regex("^[A-Za-z0-9_-]+$", var.openbao_workload_mount))
    error_message = "The OpenBao mount contains unsupported characters."
  }
}

variable "openbao_workload_path" {
  description = "OpenBao KV v2 path read by the consumer."
  type        = string
  default     = "consumer"
  nullable    = false

  validation {
    condition = (
      can(regex("^[A-Za-z0-9_/-]+$", var.openbao_workload_path)) &&
      !startswith(var.openbao_workload_path, "/") &&
      !endswith(var.openbao_workload_path, "/") &&
      !strcontains(var.openbao_workload_path, "//")
    )
    error_message = "The OpenBao path must be a safe relative path without empty segments."
  }
}

variable "admin_username" {
  description = "Administrative username required by the VM model."
  type        = string
  default     = "azureadmin"
  nullable    = false
}

variable "ssh_public_key_path" {
  description = "Path to an SSH public key; the consumer has no inbound SSH rule."
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
  nullable    = false
}

variable "vm_size" {
  description = "Azure VM size used by the disposable consumer."
  type        = string
  default     = "Standard_B2s_v2"
  nullable    = false
}

variable "image_version" {
  description = "Pinned Canonical Ubuntu 24.04 image version."
  type        = string
  default     = "24.04.202608020"
  nullable    = false
}

variable "tags" {
  description = "Tags assigned to the workload-identity resources."
  type        = map(string)
  default = {
    environment  = "learning"
    example      = "06-workload-identity"
    "managed-by" = "opentofu"
    state        = "azure-blob"
  }
}
