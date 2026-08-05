variable "resource_group_name" {
  description = "Name of the Azure resource group created by this example."
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
  description = "Azure region used for the resource group's metadata."
  type        = string
  default     = "westeurope"
  nullable    = false

  validation {
    condition     = length(trimspace(var.location)) > 0
    error_message = "The Azure location must not be empty."
  }
}

variable "tags" {
  description = "Tags assigned to the Azure resource group."
  type        = map(string)
  default = {
    environment  = "learning"
    example      = "01-resource-group"
    "managed-by" = "opentofu"
  }
}
