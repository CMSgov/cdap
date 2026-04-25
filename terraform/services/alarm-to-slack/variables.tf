variable "app" {
  description = "The application name (bcda, cdap)"
  type        = string
  validation {
    condition     = contains(["bcda", "cdap"], var.app)
    error_message = "Valid values for app are bcda, cdap."
  }
}

variable "env" {
  description = "The application environment (test, prod)"
  type        = string
  validation {
    condition     = contains(["test", "prod"], var.env)
    error_message = "Valid values for env are test, prod."
  }
}

variable "apps_served" {
  description = "List of app names whose Slack webhook URLs this function reads from SSM at runtime."
  type        = list(string)
  default     = ["bcda", "cdap", "dpc"]
}
