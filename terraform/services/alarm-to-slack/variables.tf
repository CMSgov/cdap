variable "app" {
  description = "The application name (bcda, cdap)"
  type        = string
  validation {
    condition     = contains(["bcda", "cdap"], var.app)
    error_message = "Valid values for app are bcda, cdap."
  }
}

variable "env" {
  description = "The application environment (test, prod)"
  type        = string
  validation {
    condition     = contains(["test", "prod"], var.env)
    error_message = "Valid values for env are test, prod."
  }
}
