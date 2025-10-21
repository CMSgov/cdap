variable "env" {
  description = "The application environment (test, prod, mgmt)"
  type        = string
  validation {
    condition     = contains(["test", "prod", "mgmt"], var.env)
    error_message = "Valid value for env is test, prod, or mgmt."
  }
}
