variable "env" {
  description = "Deployment environment. Controls which CDAP private location is used: 'prod' and 'sandbox' use 'cdap-prod'; all other values use 'cdap-non-prod'."
  type        = string
}

variable "app" {
  description = "Application name used in test names and tags (e.g. ab2d, bcda, dpc)."
  type        = string
}

variable "shadow_mode" {
  description = "When true, marks tests with shadow-mode:true. Should match the shadow_mode setting used in the companion datadog_monitors module."
  type        = bool
  default     = false
}

variable "tests" {
  description = <<-EOT
    List of synthetic tests to create. Each test is automatically routed through the
    CDAP-provided Datadog private location for the given environment.

    Supported subtypes and their required request_definition fields:
      - tcp:  host, port
      - http: method, url
      - ssl:  host (port optional, defaults to 443)
      - dns:  host

    Assertion operators follow Datadog conventions (e.g. "lessThan", "is", "contains").
  EOT
  type = list(object({
    name    = string
    type    = optional(string, "api")
    subtype = string
    status  = optional(string, "live")

    request_definition = object({
      host   = optional(string)
      port   = optional(number)
      method = optional(string)
      url    = optional(string)
    })

    assertions = list(object({
      type     = string
      operator = string
      target   = optional(string)
      property = optional(string)
      targetjsonpath = optional(object({
        jsonpath    = string
        operator    = string
        targetvalue = string
      }))
    }))

    tick_every = optional(number, 60)
    tags       = optional(list(string), [])
  }))
  default = []
}
