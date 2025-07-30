variable "app" {
  description = "The application name (bcda, dpc)"
  type        = string
  validation {
    condition     = contains(["bcda", "dpc"], var.app)
    error_message = "Valid value for app is bcda or dpc."
  }
}

variable "env" {
  description = "The application environment (dev, test, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "test", "prod"], var.env)
    error_message = "Valid value for env is dev, test, or prod."
  }
}
