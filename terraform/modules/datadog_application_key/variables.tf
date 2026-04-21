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
  type    = bool
  default = false
}

variable "dashboard_manager" {
  type    = bool
  default = false
}

variable "monitors_manager" {
  type    = bool
  default = false
}

variable "users_manager" {
  type    = bool
  default = false
}
