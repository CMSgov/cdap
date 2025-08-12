variable "bucket_name" {
  description = "Origin bucket name; ex: 'bcda.cms.gov2025????????????000000001'."
  type        = string
}

variable "domain" {
  description = "FQDN of the website. Ex.: 'stage.bcda.cms.gov'."
  type        = string
}

variable "enabled" {
  default     = true
  description = "Whether the distribution is enabled to accept end user requests for content."
  type        = bool
}

variable "web_acl_arn" {
  description = "ARN of the WAF web acl associated with the distribution."
  type        = string
}
