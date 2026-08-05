variable "resource_group_name" {
  description = "Name of the resource group containing the remote-state backend."
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

variable "storage_account_name" {
  description = "Globally unique name of the Azure Storage account used for state."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z0-9]{3,24}$", var.storage_account_name))
    error_message = "The storage account name must contain 3 to 24 lowercase letters or digits."
  }
}

variable "container_name" {
  description = "Name of the private blob container used for state files."
  type        = string
  default     = "tfstate"
  nullable    = false

  validation {
    condition = (
      length(var.container_name) >= 3 &&
      length(var.container_name) <= 63 &&
      can(regex("^[a-z0-9][a-z0-9-]*[a-z0-9]$", var.container_name)) &&
      !strcontains(var.container_name, "--")
    )
    error_message = "The container name must be a valid 3 to 63 character Azure container name."
  }
}

variable "state_key" {
  description = "Blob name used for the workload state file."
  type        = string
  default     = "02-remote-state/workload.tfstate"
  nullable    = false

  validation {
    condition = (
      can(regex("^[A-Za-z0-9._/-]+$", var.state_key)) &&
      !startswith(var.state_key, "/") &&
      !endswith(var.state_key, "/") &&
      !strcontains(var.state_key, "//")
    )
    error_message = "The state key must be a path-like blob name without spaces or empty segments."
  }
}

variable "location" {
  description = "Azure region used for the backend resources."
  type        = string
  default     = "westeurope"
  nullable    = false

  validation {
    condition     = length(trimspace(var.location)) > 0
    error_message = "The Azure location must not be empty."
  }
}

variable "retention_days" {
  description = "Number of days soft-deleted blobs and containers are retained."
  type        = number
  default     = 7
  nullable    = false

  validation {
    condition = (
      var.retention_days >= 1 &&
      var.retention_days <= 365 &&
      floor(var.retention_days) == var.retention_days
    )
    error_message = "Retention days must be a whole number between 1 and 365."
  }
}

variable "tags" {
  description = "Tags assigned to the backend resource group and storage account."
  type        = map(string)
  default = {
    environment  = "learning"
    example      = "02-remote-state"
    "managed-by" = "opentofu"
  }
}
