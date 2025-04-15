variable "app" {
  description = "The application name (ab2d, bcda, dpc, cdap)"
  type        = string
  validation {
    condition     = contains(["ab2d", "bcda", "dpc", "cdap"], var.app)
    error_message = "Valid value for app is ab2d, bcda, cdap, or dpc."
  }
}

variable "env" {
  description = "The application environment (dev, test, sbx, prod, mgmt)"
  type        = string
  validation {
    condition     = contains(["dev", "test", "sbx", "prod", "mgmt"], var.env)
    error_message = "Valid value for env is dev, test, sbx, mgmt or prod."
  }
}

variable "legacy" {
  description = "Is this deployment in the greenfield environment (false)?"
  type        = bool
  default     = true
}
