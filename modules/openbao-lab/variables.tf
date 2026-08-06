variable "resource_group_name" {
  description = "Name of the resource group that contains the OpenBao resources."
  type        = string
  nullable    = false

  validation {
    condition     = length(trimspace(var.resource_group_name)) > 0
    error_message = "The resource group name must not be empty."
  }
}

variable "location" {
  description = "Azure region for the OpenBao resources."
  type        = string
  nullable    = false

  validation {
    condition     = length(trimspace(var.location)) > 0
    error_message = "The Azure location must not be empty."
  }
}

variable "deployment_name" {
  description = "Name fragment used for the network, public IP, NSG, NIC, and VM."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,30}[a-z0-9]$", var.deployment_name))
    error_message = "The deployment name must contain 3 to 32 lowercase letters, digits, or hyphens."
  }
}

variable "computer_name" {
  description = "Host name assigned to the Linux VM."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-zA-Z0-9][a-zA-Z0-9-]{0,13}[a-zA-Z0-9]$", var.computer_name))
    error_message = "The computer name must contain 2 to 15 letters, digits, or hyphens."
  }
}

variable "node_id" {
  description = "Stable OpenBao Raft node identifier."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{0,62}$", var.node_id))
    error_message = "The OpenBao node ID must contain 1 to 63 lowercase letters, digits, or hyphens."
  }
}

variable "subnet_name" {
  description = "Name of the OpenBao subnet."
  type        = string
  nullable    = false
}

variable "os_disk_name" {
  description = "Name of the VM operating-system disk."
  type        = string
  nullable    = false
}

variable "raft_disk_name" {
  description = "Name of the managed disk used for OpenBao Raft data."
  type        = string
  nullable    = false
}

variable "virtual_network_address_space" {
  description = "Address space assigned to the virtual network."
  type        = list(string)
  nullable    = false

  validation {
    condition = (
      length(var.virtual_network_address_space) > 0 &&
      alltrue([for cidr in var.virtual_network_address_space : can(cidrnetmask(cidr))])
    )
    error_message = "Provide at least one valid CIDR for the virtual network."
  }
}

variable "subnet_address_prefixes" {
  description = "Address prefixes assigned to the OpenBao subnet."
  type        = list(string)
  nullable    = false

  validation {
    condition = (
      length(var.subnet_address_prefixes) > 0 &&
      alltrue([for cidr in var.subnet_address_prefixes : can(cidrnetmask(cidr))])
    )
    error_message = "Provide at least one valid CIDR for the subnet."
  }
}

variable "private_ip_address" {
  description = "Static private IPv4 address assigned to the OpenBao VM."
  type        = string
  nullable    = false

  validation {
    condition     = can(cidrhost("${var.private_ip_address}/32", 0)) && !strcontains(var.private_ip_address, ":")
    error_message = "The private IP address must be a valid IPv4 address."
  }
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
  description = "Regionally unique label for the VM's cloudapp.azure.com hostname."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,48}[a-z0-9]$", var.dns_label))
    error_message = "The DNS label must contain 3 to 50 lowercase letters, digits, or hyphens."
  }
}

variable "admin_username" {
  description = "SSH administrator username for the VM."
  type        = string
  nullable    = false
}

variable "ssh_public_key" {
  description = "OpenSSH public key used for VM administration."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^(ssh-(rsa|ed25519)|ecdsa-sha2-nistp(256|384|521)) [A-Za-z0-9+/]+={0,3}( .*)?$", trimspace(var.ssh_public_key)))
    error_message = "The SSH public key must use a supported OpenSSH public-key format."
  }
}

variable "system_assigned_identity_enabled" {
  description = "Whether the VM receives the system identity required by Azure Monitor Agent."
  type        = bool
  default     = false
}

variable "vm_size" {
  description = "Azure VM size for the disposable single-node lab."
  type        = string
  nullable    = false
}

variable "image_version" {
  description = "Pinned Canonical Ubuntu 24.04 image version."
  type        = string
  nullable    = false
}

variable "openbao_version" {
  description = "Pinned OpenBao package version installed by cloud-init."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+$", var.openbao_version))
    error_message = "The OpenBao version must use semantic version form such as 2.6.1."
  }
}

variable "openbao_gpg_fingerprint" {
  description = "Expected fingerprint of the OpenBao package-signing key."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[A-F0-9]{40}$", var.openbao_gpg_fingerprint))
    error_message = "The signing-key fingerprint must contain 40 uppercase hexadecimal characters."
  }
}

variable "tags" {
  description = "Tags assigned to the OpenBao resources."
  type        = map(string)
  default     = {}
}
