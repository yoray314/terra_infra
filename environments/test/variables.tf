variable "resource_group_name" {
  description = "Name of the disposable test resource group."
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

variable "location" {
  description = "Azure region used for the test environment."
  type        = string
  default     = "eastus"
  nullable    = false
}

variable "caller_ipv4_cidr" {
  description = "Operator public IPv4 address in /32 CIDR notation."
  type        = string
  nullable    = false

  validation {
    condition = (
      can(cidrnetmask(var.caller_ipv4_cidr)) &&
      endswith(var.caller_ipv4_cidr, "/32") &&
      !strcontains(var.caller_ipv4_cidr, ":") &&
      !can(regex("^(10\\.|127\\.|169\\.254\\.|192\\.168\\.|172\\.(1[6-9]|2[0-9]|3[01])\\.)", var.caller_ipv4_cidr))
    )
    error_message = "The caller CIDR must be a public IPv4 address in /32 notation."
  }
}

variable "dns_label" {
  description = "Regionally unique DNS label for the test VM."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,48}[a-z0-9]$", var.dns_label))
    error_message = "The DNS label must contain 3 to 50 lowercase letters, digits, or hyphens."
  }
}

variable "admin_username" {
  description = "SSH administrator username for the test VM."
  type        = string
  default     = "azureadmin"
  nullable    = false
}

variable "ssh_public_key_path" {
  description = "Path to an existing SSH public key used for VM administration."
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
  nullable    = false
}

variable "vm_size" {
  description = "Azure VM size for the test environment."
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

variable "openbao_version" {
  description = "Pinned OpenBao package version installed by cloud-init."
  type        = string
  default     = "2.6.1"
  nullable    = false
}

variable "openbao_gpg_fingerprint" {
  description = "Expected fingerprint of the OpenBao package-signing key."
  type        = string
  default     = "66D15FDD87287219C8E15478D200CD702853E6D0"
  nullable    = false
}

variable "tags" {
  description = "Additional tags merged onto the test resources."
  type        = map(string)
  default     = {}
}
