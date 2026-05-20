variable "app" {
  description = "The application name (ab2d, bbapi, bcda, cdap dpc)"
  type        = string
  validation {
    condition     = contains(["ab2d", "bbapi", "bcda", "cdap", "dpc"], var.app)
    error_message = "Valid value for app is ab2d, bbapi, bcda, cdap or dpc."
  }
}

variable "custom_widgets" {
  description = "Custom widgets to add to the dashboard. See README for details."
  type        = list(any)
  default     = []
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
  })
  default = {} # Evaluates to all true based on the optional defaults above
}

variable "name_rewrite" {
  description = "Allows for the creation of unique dashboards per application. Currently used only for development."
  type        = string
  default     = null
}
