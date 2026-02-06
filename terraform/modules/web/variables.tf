variable "domain_name" {
  description = "An externally managed domain that points to this distribution. A matching ACM certificate must already be issued."
  type        = string
}

variable "platform" {
  description = "Object representing the CDAP plaform module."
  type        = any
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

variable "allowed_ips_list" {
  sensitive   = true
  default     = []
  description = "The IPs that firewall allows to access service. Please treat these values as sensitive."
  type        = list(string)
}

variable "existing_ip_sets" {
  default     = []
  description = "Optional. Provide ARN. Attaches existing IP sets to the firewall. Favor a dedicated allowed list over existing IP sets."
  type        = list(any)
}

variable "s3_origin_id" {
  default     = "s3_origin"
  description = "Variable to manage existing s3 origins without recreation. All new instances of this module can leave the default."
  type        = string
}
