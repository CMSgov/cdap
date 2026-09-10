variable "app" {
  description = "The application name (ab2d, bcda, dpc)"
  type        = string
  default     = "cdap"
}

variable "env" {
  description = "The application environment (dev, test, sbx, sandbox, prod)"
  type        = string
  validation {
    condition     = contains(["non-prod", "test", "prod"], var.env)
    error_message = "Valid value for env is dev, non-prod, or prod."
  }
}
