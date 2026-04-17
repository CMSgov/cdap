variable "app" {
  description = "The application name (ab2d, bcda, cdap dpc)"
  type        = string
  validation {
    condition     = contains(["ab2d", "bcda", "cdap", "dpc"], var.app)
    error_message = "Valid value for app is ab2d, bcda, cdap or dpc."
  }
}
