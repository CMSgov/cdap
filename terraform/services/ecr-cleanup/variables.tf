variable "app" {
  description = "The application name is supported (dpc)"
  type        = string
  validation {
    condition     = contains(["dpc"], var.app)
    error_message = "Valid values for app is only dpc."
  }
}

# ECR images are shared across environments for each account, so only "test" and "prod" are required
variable "env" {
  description = "The application environment"
  type        = string
  validation {
    condition     = contains(["test", "prod"], var.env)
    error_message = "Valid values for env are dev, test, sandbox, prod."
  }
}

