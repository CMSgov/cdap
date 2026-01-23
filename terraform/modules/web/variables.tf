variable "domain_name" {
  description = "An externally managed domain that points to this distribution. A matching ACM certificate must already be issued."
  type        = string
}

variable "platform" {
  description = "Object representing the CDAP plaform module."
  type = object({
    app                   = string,
    env                   = string,
    ssm                   = any,
    splunk_logging_bucket = any,
    aws_caller_identity   = any,
  })
}

variable "service" {
  description = "Friendly name for this service. Do not include app, env."
  default     = "static-site"
  type        = string
}

variable "redirects" {
  description = "Map of redirects to be passed to the CloudFront redirects function."
  type        = map(string)
}

variable "enabled" {
  default     = true
  description = "Whether the distribution is enabled to accept end user requests for content."
  type        = bool
}

variable "waf_ip_allow_list_keyname" {
  default     = "waf_ip_allow_list"
  description = "The friendly name used to store the IP allow list in sops and ssm. Do not include full path construction."
  type        = string
}

variable "allowed_ips_list" {
  default     = []
  description = "Repositories using sops leave this blank. After sops migration, deprecate this variable. The IPs that firewall allows to access service."
  type        = list(string)
}

variable "existing_ip_sets" {
  default     = []
  description = "Optional. Attaches existing IP sets to the firewall. Favor a dedicated allowed list over existing IP sets."
  type        = list(any)
}

variable "s3_origin_id" {
  default     = "s3_origin"
  description = "Variable to manage existing s3 origins without recreation. All new instances of this module can leave the default."
  type        = string
}
