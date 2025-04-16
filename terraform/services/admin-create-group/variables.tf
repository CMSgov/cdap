variable "app" {
  description = "The application name (bcda)"
  type        = string
  validation {
    condition     = contains(["bcda"], var.app)
    error_message = "Valid value for app is bcda."
  }
}

variable "env" {
  description = "The application environment (dev, test, sbx, sandbox, mgmt, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "test", "sbx", "sandbox", "prod", "mgmt"], var.env)
    error_message = "Valid value for env is dev, test, sbx, sandbox, mgmt or prod."
  }
}
