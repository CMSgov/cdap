variable "env" {
  description = "The application environment (test, prod)"
  type        = string
  validation {
    condition     = contains(["test", "prod"], var.env)
    error_message = "Valid value for env is test, prod."
  }
}

variable "event_rule_enabled" {
  description = "Override for event_rule.enabled in config/<env>.yml. Leave null to use the config file."
  type        = bool
  default     = null
}
