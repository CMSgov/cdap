variable "app" {
  description = "The application name (ab2d, bb, bcda, cdap dpc)"
  type        = string
}

variable "custom_widgets" {
  description = "Custom widgets to add to the dashboard. See README for details."
  type        = list(any)
  default     = []
}

variable "widget_live_spans" {
  description = "Live span overrides for specific dashboard sections. Valid values: 5m, 10m, 15m, 30m, 1h, 4h, 1d, 2d, 1w, 1mo"
  type = object({
    current = optional(string, "15m") # short window for point-in-time accuracy
    ecs     = optional(string, "1d")  # ECS utilization, events, restarts
    apm     = optional(string, "1h")  # Request rate, latency, error rate
    alb     = optional(string, "1d")  # Request counts, response times
    sqs     = optional(string, "4h")  # Message counts, DLQ depth
    sns     = optional(string, "4h")  # Published, delivered, failed
    lambda  = optional(string, "2d")  # Invocations, errors, duration
    aurora  = optional(string, "4h")  # CPU, IOPS, latency, replica lag
    s3      = optional(string, "1w")  # S3 metrics update daily — needs wide window
  })
  default = {}
}

variable "enable_default_widgets" {
  description = "Toggle default infrastructure widgets on or off for the dashboard."
  type = object({
    monitors = optional(bool, true)
    ecs      = optional(bool, true)
    lambda   = optional(bool, true)
    alb      = optional(bool, true)
    sns      = optional(bool, true)
    sqs      = optional(bool, true)
    aurora   = optional(bool, true)
    s3       = optional(bool, true)
    apm      = optional(bool, true)
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
