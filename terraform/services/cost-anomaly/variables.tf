variable "env" {
  description = "The application environment (dev, test, mgmt, sandbox, prod)"
  type        = string
  validation {
    condition     = contains(["test", "prod"], var.env)
    error_message = "Valid value for env is dev, test, mgmt, sandbox, or prod."
  }
}
