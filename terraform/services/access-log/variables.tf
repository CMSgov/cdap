variable "app" {
  description = "The application name ( bcda, dpc)"
  type        = string
  validation {
    condition     = contains(["bcda", "dpc"], var.app)
    error_message = "Valid value for app is bcda, or dpc."
  }
}
