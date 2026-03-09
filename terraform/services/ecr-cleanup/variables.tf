variable "app" {
  description = "The application name is supported (dpc)"
  type        = string
  validation {
    condition     = contains(["dpc"], var.app)
    error_message = "Valid values for app is only dpc."
  }
}

variable "env" {
  description = "The application environment"
  type        = string
  validation {
    condition     = contains(["dev", "test", "sandbox", "prod"], var.env)
    error_message = "Valid values for env are dev, test, sandbox, prod."
  }
}

