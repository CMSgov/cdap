variable "app" {
  description = "The application name"
  type        = string
  default     = "cdap"
  validation {
    condition     = var.app == "cdap"
    error_message = "This service only supports app = cdap."
  }
}

variable "env" {
  description = "The application environment (test, prod)"
  type        = string
  validation {
    condition     = contains(["test", "prod"], var.env)
    error_message = "Valid value for env is test, prod."
  }
}
