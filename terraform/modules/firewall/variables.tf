variable "app" {
  default     = null
  description = "The application name (ab2d, bcda, dpc or null)."
  type        = string
}

variable "scope" {
  description = "Firewall scope"
  type        = string
  validation {
    condition     = contains(["CLOUDFRONT", "REGIONAL"], var.scope)
    error_message = "Valid value for scope is CLOUDFRONT or REGIONAL."
  }
}

variable "name" {
  description = "Web ACL name"
  type        = string
}

variable "associated_resource_arn" {
  description = "ARN of the resource to associate the WAF with."
  type        = string
  default     = ""
}

variable "content_type" {
  description = "Content type for firewall responses"
  type        = string
  validation {
    condition     = contains(["APPLICATION_JSON", "TEXT_HTML", "TEXT_PLAIN"], var.content_type)
    error_message = "Valid value for content_type is APPLICATION_JSON, TEXT_HTML, or TEXT_PLAIN."
  }
}

variable "rate_limit" {
  description = "IP rate limit for every 5 minutes"
  type        = number
  default     = 3000
}

variable "ip_sets" {
  description = "IP sets to allow"
  type        = list(string)
  default     = []
}
