variable "domain_name" {
  description = "An externally managed domain that points to this distribution. A matching ACM certificate must already be issued."
  type        = string
}

variable "origin_bucket" {
  description = "Object representing the origin S3 bucket."
  type = object({
    bucket_regional_domain_name = string,
    arn                         = string,
    id                          = string
  })
}

variable "platform" {
  description = "Object representing the CDAP plaform module."
  type = object({
    app = string,
    env = string,
    splunk_logging_bucket = object({
      arn = string
    })
  })
}

variable "redirects" {
  description = "Map of redirects to be passed to the CloudFront redirects function."
  type        = map(string)
}

variable "web_acl" {
  description = "Object representing the associated WAF acl."
  type = object({
    arn = string
  })
}

variable "enabled" {
  default     = true
  description = "Whether the distribution is enabled to accept end user requests for content."
  type        = bool
}

variable "s3_origin_id" {
  default     = "s3_origin"
  description = "Variable to manage existing s3 origins without recreation. All new instances of this module can leave the default."
  type        = string
}
