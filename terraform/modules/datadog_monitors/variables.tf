variable "app" {
  description = "The application name (ab2d, bb, bfd, bcda, cdap dpc)"
  type        = string
}

variable "env" {
  description = "Deployment environment (dev, test, sandbox, stage, prod)"
  type        = string
}

variable "monitor_config" {
  type = object({
    shadow_mode = optional(bool, true)

    notifications = optional(object({
      victorops           = optional(bool, false)
      slack               = optional(bool, false)
      emails              = optional(list(string), [])
      additional_webhooks = optional(list(string), [])
    }), {})

    enabled = optional(object({
      ecs    = optional(bool, true)
      sqs    = optional(bool, true)
      sns    = optional(bool, true)
      lambda = optional(bool, true)
      s3     = optional(bool, true)
      rds    = optional(bool, true)
    }), {})

    ecs = optional(object({
      cpu_threshold             = optional(number, 85)
      memory_threshold          = optional(number, 85)
      notify_no_data            = optional(bool, false)
      no_data_timeframe_minutes = optional(number, 10)
      timeframe                 = optional(string, "last_10m")
    }), {})

    sqs = optional(object({
      dlq_message_threshold     = optional(number, 1)
      max_message_age_seconds   = optional(number, 300)
      notify_no_data            = optional(bool, false)
      no_data_timeframe_minutes = optional(number, 10)
      timeframe                 = optional(string, "last_5m")
    }), {})

    sns = optional(object({
      failed_notification_threshold = optional(number, 5)
      notify_no_data                = optional(bool, false)
      no_data_timeframe_minutes     = optional(number, 10)
      timeframe                     = optional(string, "last_5m")
    }), {})

    lambda = optional(object({
      error_rate_threshold      = optional(number, 5)
      throttle_threshold        = optional(number, 10)
      duration_p99_threshold_ms = optional(number, 8000)
      notify_no_data            = optional(bool, false)
      no_data_timeframe_minutes = optional(number, 10)
      timeframe                 = optional(string, "last_5m")
    }), {})

    s3 = optional(object({
      http_response_4xx_threshold = optional(number, 50)
      http_response_5xx_threshold = optional(number, 10)
      notify_no_data              = optional(bool, false)
      no_data_timeframe_minutes   = optional(number, 10)
      timeframe                   = optional(string, "last_5m")
    }), {})

    rds = optional(object({
      cpu_threshold                = optional(number, 85)
      freeable_memory_threshold_mb = optional(number, 256)
      db_connections_threshold     = optional(number, 200)
      replica_lag_seconds          = optional(number, 30)
      deadlock_threshold           = optional(number, 1)
      deadlocks_enabled            = optional(bool, true)
      notify_no_data               = optional(bool, false)
      no_data_timeframe_minutes    = optional(number, 10)
      timeframe                    = optional(string, "last_10m")
    }), {})
  })
  default = {}
}

variable "custom_monitors" {
  description = "Custom monitors to create. Module handles notify, shadow_mode, and base_tags automatically."
  type = list(object({
    name    = string
    type    = optional(string, "metric alert")
    message = string
    query   = string
    thresholds = object({
      critical          = number
      warning           = optional(number)
      critical_recovery = optional(number)
      warning_recovery  = optional(number)
    })
    notify_no_data            = optional(bool, false)
    no_data_timeframe_minutes = optional(number, 60)
    require_full_window       = optional(bool, true)
    tags                      = optional(list(string), [])
    create                    = optional(bool, true)
  }))
  default = []
}
