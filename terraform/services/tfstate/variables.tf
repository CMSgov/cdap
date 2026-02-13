variable "app" {
  description = "The application name (ab2d, bcda, dpc, cdap, dasg-insights)"
  type        = string
  validation {
    condition     = contains(["ab2d", "bcda", "dpc", "cdap", "dasg-insights"], var.app)
    error_message = "Valid value for app is ab2d, bcda, dpc, cdap, or dasg-insights."
  }
}

variable "env" {
  description = "The application environment (dev, test, sandbox, prod, mgmt)"
  type        = string
  validation {
    condition     = contains(["dev", "test", "sandbox", "prod", "mgmt"], var.env)
    error_message = "Valid value for env is dev, test, sandbox, prod, or mgmt."
  }
}
