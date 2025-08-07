variable "app" {
  description = "Name of the associated DASG application."
  type        = string
  validation {
    condition     = contains(["ab2d", "bcda", "dpc"], var.app)
    error_message = "Invalid app. Allowed values are 'ab2d', 'bcda', or 'dpc'."
  }
}

variable "enabled" {
  default     = true
  description = "(Required) - Whether the distribution is enabled to accept end user requests for content."
  type        = bool
}

variable "staging" {
  default     = false
  description = "A Boolean that indicates whether this is a staging distribution. Defaults to false."
  type        = bool
}
