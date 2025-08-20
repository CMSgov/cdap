variable "bucket" {
  description = "Object representing the origin S3 bucket."
  type        = map
}

variable "certificate" {
  description = "Object representing the website certificate."
  type = object({
    arn         = string
    domain_name = string
  })
}

variable "default_cache_behavior" {
  default     = {
    cache_policy_id       = null
    function_association  = []
  }
  description = "Default cache behavior for this distribution."
  type        = object({
    cache_policy_id       = optional(string)
    function_association  = list(object({
      event_type    = string
      function_arn  = string
    }))
  })
}

variable "enabled" {
  default     = true
  description = "Whether the distribution is enabled to accept end user requests for content."
  type        = bool
}

variable "web_acl" {
  description = "Object representing the associated WAF acl."
  type        = map
}
