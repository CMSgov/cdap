variable "app" {
  description = "[\"ab2d\", \"bcda\", \"dpc\", \"cdap\", \"bbapi\"] The application name."
  type        = string
  validation {
    condition     = contains(["ab2d", "bcda", "dpc", "cdap", "bbapi"], var.app)
    error_message = "Valid value for app is ab2d, bbapi, bcda, dpc, cdap."
  }
}

variable "env" {
  description = "[\"dev\", \"test\", \"sandbox\", \"prod\", \"non-prod\"] The environment that leverages this key."
  type        = string
  validation {
    condition     = contains(["dev", "test", "sandbox", "prod", "non-prod"], var.env)
    error_message = "Valid value for app is dev, test, sandbox, or prod."
  }
}

variable "api_key_manager" {
  description = "Allows creation and deletion of API keys. Due to limited number of keys, restricted to CDAP for oversight."
  type        = bool
  default     = false
}

variable "dashboard_manager" {
  description = "Allows for creation and deletion of dashboards. All subscriber repos can use."
  type        = bool
  default     = false
}

variable "monitors_manager" {
  description = "Allows for creation and deletion of monitors. All subscriber repos can use."

  type    = bool
  default = false
}

variable "users_manager" {
  description = "Allows for management of users into teams. Currently no use cases."
  type        = bool
  default     = false
}

variable "org_config_manager" {
  type    = bool
  default = false
}
