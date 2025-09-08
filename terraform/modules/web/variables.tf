variable "bucket" {
  description = "Object representing the origin S3 bucket."
  type        = any
}

variable "certificate" {
  default     = null
  description = "Object representing the website certificate."
  type = object({
    arn         = string
    domain_name = string
  })
}

variable "enabled" {
  default     = true
  description = "Whether the distribution is enabled to accept end user requests for content."
  type        = bool
}

variable "platform" {
  description = "Object representing the CDAP plaform module."
  type        = any
}

variable "viewer_request_function_list" {
  default     = []
  description = "Optional list of viewer request function definitions to associate with the distribution."
  type          = list(object({
    code        = string
    comment     = string
    name        = string
    runtime     = string
  }))
}

variable "web_acl" {
  description = "Object representing the associated WAF acl."
  type        = any
}
