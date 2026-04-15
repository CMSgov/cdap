variable "account_env_suffix" {
  description = "[\"prod\" or \"non-prod\"] The AWS account shorthand to distinguish environment hierarchy."
  type        = string
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
