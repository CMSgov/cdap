variable "env" {
  description = "The application environment (test, prod)"
  type        = string
  validation {
    condition     = contains(["test", "prod"], var.env)
    error_message = "Valid values for env are test, prod."
  }
}

variable "app" {
  description = "The application name (ab2d, bcda, cdap, dpc)"
  type        = string
  validation {
    condition     = contains(["ab2d", "bcda", "cdap", "dpc"], var.app)
    error_message = "Valid values for app are ab2d, bcda, cdap, or dpc."
  }
}
