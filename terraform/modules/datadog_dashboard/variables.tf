variable "app" {
  description = "The application name (ab2d, bb, bcda, cdap dpc)"
  type        = string
  validation {
    condition     = contains(["ab2d", "bb", "bcda", "cdap", "dpc"], var.app)
    error_message = "Valid value for app is ab2d, bb, bcda, cdap or dpc."
  }
}

variable "custom_widgets" {
  description = "Custom widgets to add to the dashboard. See README for details."
  type        = list(any)
  default     = []
}

variable "widget_live_spans" {
  description = "Live span overrides for specific dashboard sections. Valid values: 5m, 10m, 15m, 30m, 1h, 4h, 1d, 2d, 1w, 1mo"
  type = object({
    lambda = optional(string, "2d")
    s3     = optional(string, "1w")
    sqs    = optional(string, "4h")
    sns    = optional(string, "4h")
    ecs    = optional(string, "1d")
    alb    = optional(string, "1d")
    aurora = optional(string, "4h")
    apm    = optional(string, "1h")
  })
  default = {}
}

variable "enable_default_widgets" {
  description = "Toggle default infrastructure widgets on or off for the dashboard."
  type = object({
    ecs    = optional(bool, true)
    lambda = optional(bool, true)
    alb    = optional(bool, true)
    sns    = optional(bool, true)
    sqs    = optional(bool, true)
    aurora = optional(bool, true)
    s3     = optional(bool, true)
    apm    = optional(bool, true)
  })
  default = {} # Evaluates to all true based on the optional defaults above
}

variable "name_rewrite" {
  description = "Allows for the creation of unique dashboards per application. Currently used only for development."
  type        = string
  default     = null
}

variable "runbook_url" {
  description = "URL where on-call engineers can find actions to remediate issues, including escalation."
  type        = string
}
