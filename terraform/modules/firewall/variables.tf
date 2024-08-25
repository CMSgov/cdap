variable "app" {
  description = "The application name (ab2d, bcda, dpc)"
  type        = string
  validation {
    condition     = contains(["ab2d", "bcda", "dpc"], var.app)
    error_message = "Valid value for app is ab2d, bcda, or dpc."
  }
}

variable "env" {
  description = "The application environment (dev, test, sbx, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "test", "sbx", "prod"], var.env)
    error_message = "Valid value for env is dev, test, sbx, or prod."
  }
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
