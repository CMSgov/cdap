variable "domain" {
  description = "FQDN of the website. Ex.: 'stage.bcda.cms.gov'."
  type        = string
}

variable "enabled" {
  default     = true
  description = "(Required) - Whether the distribution is enabled to accept end user requests for content."
  type        = bool
}
