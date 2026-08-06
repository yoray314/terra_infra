variable "resource_group_name" {
  description = "Name of the resource group containing shared monitoring resources."
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

variable "workspace_name" {
  description = "Globally unique name of the Log Analytics workspace."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[A-Za-z0-9][A-Za-z0-9-]{2,61}[A-Za-z0-9]$", var.workspace_name))
    error_message = "The workspace name must contain 4 to 63 letters, digits, or hyphens."
  }
}

variable "openbao_resource_group_name" {
  description = "Resource group containing the existing Example 04 OpenBao VM."
  type        = string
  default     = "rg-opentofu-openbao"
  nullable    = false
}

variable "openbao_virtual_machine_name" {
  description = "Name of the existing Example 04 OpenBao VM."
  type        = string
  default     = "vm-openbao-lab"
  nullable    = false
}

variable "key_vault_resource_group_name" {
  description = "Resource group containing the existing Example 03 Key Vault."
  type        = string
  default     = "rg-opentofu-key-vault"
  nullable    = false
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

variable "alert_email_address" {
  description = "Email address that receives Azure Monitor alert notifications."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", var.alert_email_address))
    error_message = "The alert receiver must be a syntactically valid email address."
  }
}

variable "alerts_enabled" {
  description = "Whether verified telemetry creates saved queries and three enabled alert rules."
  type        = bool
  default     = false
}

variable "daily_quota_gb" {
  description = "Daily Log Analytics ingestion cap in GB for the learning workspace."
  type        = number
  default     = 0.5

  validation {
    condition     = var.daily_quota_gb >= 0.1 && var.daily_quota_gb <= 5
    error_message = "The daily ingestion cap must be between 0.1 and 5 GB."
  }
}

variable "cpu_alert_threshold" {
  description = "Average VM CPU percentage that triggers the warning alert."
  type        = number
  default     = 85

  validation {
    condition     = var.cpu_alert_threshold >= 1 && var.cpu_alert_threshold <= 100
    error_message = "The CPU alert threshold must be between 1 and 100 percent."
  }
}

variable "azure_monitor_agent_version" {
  description = "Supported Azure Monitor Linux Agent handler version used as the automatic-upgrade baseline."
  type        = string
  default     = "1.43"
  nullable    = false

  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+$", var.azure_monitor_agent_version))
    error_message = "The Azure Monitor Agent handler version must use major.minor form."
  }
}

variable "tags" {
  description = "Tags assigned to the observability resources."
  type        = map(string)
  default = {
    environment  = "learning"
    example      = "11-operations-observability"
    "managed-by" = "opentofu"
    state        = "azure-blob"
  }
}
