variable "resource_group_name" {
  description = "Existing resource group delegated to the GitHub apply identity."
  type        = string
  default     = "rg-opentofu-github-workload"
  nullable    = false
}

variable "virtual_network_name" {
  description = "Name of the virtual network managed by GitHub Actions."
  type        = string
  default     = "vnet-github-oidc-lab"
  nullable    = false
}

variable "location" {
  description = "Azure region matching the delegated workload resource group."
  type        = string
  default     = "westeurope"
  nullable    = false
}

variable "address_space" {
  description = "Address space assigned to the CI-managed virtual network."
  type        = list(string)
  default     = ["10.80.0.0/16"]
  nullable    = false

  validation {
    condition = (
      length(var.address_space) > 0 &&
      alltrue([for prefix in var.address_space : can(cidrnetmask(prefix))])
    )
    error_message = "Every address-space entry must be a valid CIDR prefix."
  }
}

variable "tags" {
  description = "Tags assigned to the CI-managed workload."
  type        = map(string)
  default = {
    environment  = "learning"
    example      = "08-github-oidc"
    "managed-by" = "github-actions"
  }
}
