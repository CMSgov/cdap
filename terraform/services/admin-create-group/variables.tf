variable "app" {
  description = "The application name (bcda)"
  type        = string
  validation {
    condition     = contains(["bcda"], var.app)
    error_message = "Valid value for app is bcda."
  }
}

variable "env" {
  description = "The application environment (dev, test, sbx, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "test", "sbx", "prod"], var.env)
    error_message = "Valid value for env is dev, test, sbx, or prod."
  }
}
