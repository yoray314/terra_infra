variable "resource_group_name" {
  description = "Name of the empty landing-zone resource group protected by the initiative."
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
  description = "Azure region of the landing-zone resource group."
  type        = string
  default     = "eastus"
  nullable    = false

  validation {
    condition     = can(regex("^[a-z0-9]+$", var.location))
    error_message = "The location must use the normalized Azure region name form, such as eastus."
  }
}

variable "allowed_locations" {
  description = "Azure regions allowed for regional resources in the protected resource group."
  type        = set(string)
  default     = ["eastus"]
  nullable    = false

  validation {
    condition = (
      length(var.allowed_locations) > 0 &&
      alltrue([for location in var.allowed_locations : can(regex("^[a-z0-9]+$", location))])
    )
    error_message = "Provide at least one normalized Azure region name."
  }
}

variable "enforcement_enabled" {
  description = "Whether the resource-group initiative enforces deny effects instead of reporting only."
  type        = bool
  default     = false
}

variable "owner" {
  description = "Accountable team or service owner recorded on the landing-zone resource group."
  type        = string
  nullable    = false

  validation {
    condition     = length(trimspace(var.owner)) >= 3 && length(var.owner) <= 64
    error_message = "The owner must contain between 3 and 64 characters."
  }
}

variable "environment" {
  description = "Environment classification recorded on the landing-zone resource group."
  type        = string
  default     = "production"
  nullable    = false

  validation {
    condition     = contains(["production", "preproduction"], var.environment)
    error_message = "The environment must be production or preproduction."
  }
}

variable "data_classification" {
  description = "Highest data classification allowed in the landing zone."
  type        = string
  default     = "confidential"
  nullable    = false

  validation {
    condition     = contains(["internal", "confidential", "restricted"], var.data_classification)
    error_message = "The data classification must be internal, confidential, or restricted."
  }
}

variable "criticality" {
  description = "Business criticality recorded on the landing-zone resource group."
  type        = string
  default     = "high"
  nullable    = false

  validation {
    condition     = contains(["medium", "high", "mission-critical"], var.criticality)
    error_message = "Criticality must be medium, high, or mission-critical."
  }
}

variable "tags" {
  description = "Additional tags applied without overriding required governance tags."
  type        = map(string)
  default     = {}
}
