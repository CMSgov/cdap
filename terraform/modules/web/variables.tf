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

variable "logging_bucket" {
  description = "Object representing the logging S3 bucket."
  type        = any
}

variable "origin_bucket" {
  description = "Object representing the origin S3 bucket."
  type        = any
}

variable "platform" {
  description = "Object representing the CDAP plaform module."
  type        = any
}

variable "redirects" {
  description = "Map of redirects to be passed to the CloudFront redirects function."
  type        = map
}

variable "web_acl" {
  description = "Object representing the associated WAF acl."
  type        = any
}
