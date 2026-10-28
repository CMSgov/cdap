variable "app" {
  description = "The application name (ab2d, bcda, dpc)"
  type        = string
  validation {
    condition     = contains(["ab2d", "bcda", "dpc"], var.app)
    error_message = "Valid value for app is ab2d, bcda, or dpc."
  }
}

variable "env" {
  description = "The application environment (dev, test, sbx, sandbox, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "test", "sbx", "sandbox", "prod"], var.env)
    error_message = "Valid value for env is dev, test, sbx, sandbox, or prod."
  }
}

variable "rate_limit" {
  description = "IP rate limit for every 5 minutes. If null, defaults based on application and environment."
  type        = number
  default     = null
}
