variable "identity_resource_group_name" {
  description = "Name of the resource group containing GitHub deployment identities."
  type        = string
  default     = "rg-opentofu-github-identities"
  nullable    = false
}

variable "workload_resource_group_name" {
  description = "Name of the resource group managed by GitHub Actions."
  type        = string
  default     = "rg-opentofu-github-workload"
  nullable    = false
}

variable "location" {
  description = "Azure region used for identity and workload resource groups."
  type        = string
  default     = "westeurope"
  nullable    = false
}

variable "state_storage_resource_group_name" {
  description = "Resource group containing the Example 02 state account."
  type        = string
  default     = "rg-opentofu-state"
  nullable    = false
}

variable "state_storage_account_name" {
  description = "Name of the Example 02 state storage account."
  type        = string
  nullable    = false
}

variable "workload_state_container_name" {
  description = "Name of the dedicated container created for GitHub-managed workload state."
  type        = string
  default     = "github-state"
  nullable    = false
}

variable "plan_subject" {
  description = "Exact GitHub OIDC subject allowed to use the plan identity."
  type        = string
  nullable    = false

  validation {
    condition     = startswith(var.plan_subject, "repo:") && !strcontains(var.plan_subject, "*")
    error_message = "The plan subject must be an exact GitHub repository subject without wildcards."
  }
}

variable "apply_subject" {
  description = "Exact GitHub OIDC environment subject allowed to use the apply identity."
  type        = string
  nullable    = false

  validation {
    condition = (
      startswith(var.apply_subject, "repo:") &&
      strcontains(var.apply_subject, ":environment:") &&
      !strcontains(var.apply_subject, "*")
    )
    error_message = "The apply subject must be an exact GitHub environment subject without wildcards."
  }
}

variable "environment_protection_confirmed" {
  description = "Explicit confirmation that the GitHub lab environment requires review and master."
  type        = bool
  default     = false
  nullable    = false
}

variable "tags" {
  description = "Tags assigned to the GitHub OIDC bootstrap resources."
  type        = map(string)
  default = {
    environment  = "learning"
    example      = "08-github-oidc"
    "managed-by" = "opentofu"
  }
}
