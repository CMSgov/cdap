variable "app_permissions" {
  description = "Per-app Datadog permission overrides. Any app not listed will use the default permissions."
  type = map(object({
    api_key_manager   = optional(bool, false)
    dashboard_manager = optional(bool, true)
    monitors_manager  = optional(bool, true)
    users_manager     = optional(bool, false)
  }))
  default = {
    "cdap-test" = {
      api_key_manager = true
    }
    "cdap-prod" = {
      api_key_manager = true
    }
  }
}

variable "env" {
  description = "The application environment (test, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "sandbox", "test", "prod"], var.env)
    error_message = "Valid value for env is dev, test, sandbox, or prod."
  }
}

variable "app" {
}
