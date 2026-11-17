variable "platform" {
  description = "Object representing the CDAP platform module. Only app and env are read."
  type = object({
    app = string
    env = string
  })
}

variable "name" {
  description = <<-EOT
    Short name for this rule's purpose, e.g. "task-monitoring" or "nightly-audit".
    The rule is named {platform.app}-{platform.env}-{name}.
  EOT
  type        = string
}

variable "rule_name_override" {
  description = <<-EOT
    Overrides the constructed rule name entirely. Rule names are immutable in AWS:
    changing this destroys and recreates the rule. Use it when adopting an existing
    rule whose name predates this convention.
  EOT
  type        = string
  default     = null

  validation {
    condition     = var.rule_name_override == null || can(regex("^[\\.\\-_A-Za-z0-9]{1,64}$", var.rule_name_override))
    error_message = "rule_name_override must be 1-64 characters of letters, numbers, '.', '-' or '_'."
  }
}

variable "description" {
  description = "Description of the rule."
  type        = string
  default     = null
}

# ── What triggers the rule (set exactly one) ──────────────────────────────────

variable "schedule_expression" {
  description = <<-EOT
    A cron() or rate() expression, e.g. "rate(1 day)" or "cron(0 12 * * ? *)".
    Set this or event_pattern, not both. Schedules only run on the default event bus.
  EOT
  type        = string
  default     = null

  validation {
    condition     = var.schedule_expression == null || can(regex("^(rate|cron)\\(.+\\)$", var.schedule_expression))
    error_message = "schedule_expression must be a rate(...) or cron(...) expression."
  }
}

variable "event_pattern" {
  description = <<-EOT
    Event pattern as a JSON string; build it with jsonencode(). Set this or
    schedule_expression, not both.
  EOT
  type        = string
  default     = null

  validation {
    condition     = var.event_pattern == null || can(jsondecode(var.event_pattern))
    error_message = "event_pattern must be valid JSON. Build it with jsonencode()."
  }
}

variable "event_bus_name" {
  description = "Name or ARN of the event bus the rule watches. Leave as default unless the team owns a custom bus."
  type        = string
  default     = "default"
  nullable    = false
}

variable "enabled" {
  description = "Whether the rule is ENABLED. Set false to stop matching without destroying the rule."
  type        = bool
  default     = true
  nullable    = false
}

# ── Where matched events go ───────────────────────────────────────────────────

variable "targets" {
  description = <<-EOT
    Map of targets for the rule, keyed by target ID (unique per rule, e.g. "lambda" or
    "SendToSNS"). At most 5 per rule. Each target may set at most one of input,
    input_path or input_transformer; when none is set, the full event is delivered.

    Set lambda_permission = true on Lambda targets so the module grants
    events.amazonaws.com invoke on the function, scoped to this rule. Leave it false
    when the function's owner manages that permission. The module does not write
    resource policies for SNS or SQS
    targets, since those policies belong to the topic or queue owner; for an SNS
    target from modules/topic, set allow_eventbridge_publish = true there.

    role_arn is only needed for targets that EventBridge must assume a role to reach,
    such as ECS tasks, Kinesis streams or another event bus.
  EOT
  type = map(object({
    arn               = string
    lambda_permission = optional(bool, false)
    role_arn          = optional(string)
    input             = optional(string)
    input_path        = optional(string)
    input_transformer = optional(object({
      input_paths    = optional(map(string), {})
      input_template = string
    }))
    dead_letter_arn = optional(string)
    retry_policy = optional(object({
      maximum_event_age_in_seconds = optional(number)
      maximum_retry_attempts       = optional(number)
    }))
  }))
  default  = {}
  nullable = false

  validation {
    condition     = length(var.targets) <= 5
    error_message = "EventBridge allows at most 5 targets per rule."
  }

  validation {
    condition     = alltrue([for k in keys(var.targets) : can(regex("^[\\.\\-_A-Za-z0-9]{1,64}$", k))])
    error_message = "Target keys are used as target IDs: 1-64 characters of letters, numbers, '.', '-' or '_'."
  }

  validation {
    condition = alltrue([
      for t in values(var.targets) :
      length(compact([t.input, t.input_path, t.input_transformer == null ? null : "set"])) <= 1
    ])
    error_message = "Each target may set at most one of input, input_path or input_transformer."
  }
}
