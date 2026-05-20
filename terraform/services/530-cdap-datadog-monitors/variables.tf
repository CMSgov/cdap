variable "app" {
  description = "The application name (bcda, cdap)"
  type        = string
  default     = "cdap"
}

variable "env" {
  description = "The application environment (test, prod)"
  type        = string
  validation {
    condition     = contains(["test", "prod"], var.env)
    error_message = "Valid value for env is test, or prod."
  }
}
