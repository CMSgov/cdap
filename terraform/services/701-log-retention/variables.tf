variable "env" {
  description = "The application environment (test)"
  type        = string
  validation {
    condition     = contains(["test"], var.env)
    error_message = "Valid value for env is test (until fully validated)."
  }
}
