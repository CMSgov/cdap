variable "app_permissions" {
  description = "Per-app Datadog permission overrides. Any app not listed will use the default permissions."
  type = map(object({
    api_key_manager    = optional(bool, false)
    dashboard_manager  = optional(bool, true)
    monitors_manager   = optional(bool, true)
    users_manager      = optional(bool, false)
    org_config_manager = optional(bool, false)
  }))
  default = {
    "cdap-test" = {
      api_key_manager = true
    }
    "cdap-prod" = {
      api_key_manager    = true
      org_config_manager = true
      users_manager      = true
    }
  }
}

variable "env" {
  description = "The application environment (dev, test, sandbox, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "sandbox", "test", "prod"], var.env)
    error_message = "Valid value for env is dev, test, sandbox, or prod."
  }
}

variable "app" {
  description = "[\"ab2d\", \"bcda\", \"dpc\", \"cdap\", \"bbapi\"] The application name."
  type        = string
  validation {
    condition     = contains(["ab2d", "bcda", "dpc", "cdap", "bbapi"], var.app)
    error_message = "Valid value for app is ab2d, bcda, dpc, or cdap."
  }
}
