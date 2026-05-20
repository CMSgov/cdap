variable "app" {
  description = "The application name (bcda, cdap)"
  type        = string
  default     = "cdap"
}

variable "env" {
  description = "The application environment (dev, test, sbx, sandbox, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "test", "impl", "stage", "sandbox", "prod"], var.env)
    error_message = "Valid value for env is dev, test, sbx, sandbox, or prod."
  }
}
