variable "app" {
  description = "The application name is supported (cdap)"
  type        = string
  validation {
    condition     = contains(["cdap"], var.app)
    error_message = "Valid values for app is only cdap."
  }
}

variable "env" {
  description = "The application environment"
  type        = string
  validation {
    condition     = contains(["test", "prod"], var.env)
    error_message = "Valid values for env are test and prod."
  }
}
