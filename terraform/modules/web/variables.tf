#######################################
# aws_cloudfront_distribution variables
#######################################

variable "aliases" {
  default     = null
  description = "(Optional) - Extra CNAMEs (alternate domain names), if any, for this distribution."
  type        = list(string)
}

variable "anycast_ip_list_id" {
  default     = null
  description = "(Optional) - ID of the Anycast static IP list that is associated with the distribution."
  type        = string
}

variable "comment" {
  default     = null
  description = "(Optional) - Any comments you want to include about the distribution."
  type        = string
}

variable "custom_error_responses" {
  default     = []
  description = "(Optional) - One or more custom error response elements (multiples allowed)."
  type        = list(object({
    error_caching_min_ttl = optional(number)
    error_code            = number
    response_code         = optional(number)
    response_page_path    = optional(string)
  }))
}

variable "default_cache_behavior" {
  default     = {
    allowed_methods             = ["GET", "HEAD"]
    cached_methods              = ["GET", "HEAD"]
    default_ttl                 = 3600
    function_association        = []
    lambda_function_association = []
    max_ttl                     = 86400
    min_ttl                     = 0
    target_origin_id            = "s3_origin"
    viewer_protocol_policy      = "redirect-to-https"
  }
  description = "(Required) - Default cache behavior for this distribution (maximum one). Requires either cache_policy_id (preferred) or forwarded_values (deprecated) be set."
  type        = object({
    allowed_methods             = list(string)
    cached_methods              = list(string)
    cache_policy_id             = optional(string)
    compress                    = optional(bool)
    default_ttl                 = optional(number)
    field_level_encryption_id   = optional(string)
    grpc_config                 = optional(object({
      enabled = bool
    }))
    lambda_function_association = optional(list(object({
      event_type    = string
      lambda_arn    = string
      include_body  = bool
    })))
    function_association        = optional(list(object({
      event_type    = string
      function_arn  = string
    })))
    max_ttl                     = optional(number)
    min_ttl                     = optional(number)
    origin_request_policy_id    = optional(string)
    realtime_log_config_arn     = optional(string)
    response_headers_policy_id  = optional(string)
    smooth_streaming            = optional(bool)
    target_origin_id            = string
    trusted_key_groups          = optional(list(string))
    trusted_signers             = optional(list(string))
    viewer_protocol_policy      = string
  })
}

variable "default_root_object" {
  default     = null
  description = "(Optional) - Object that you want CloudFront to return (for example, index.html) when an end user requests the root URL."
  type        = string
} 

variable "enabled" {
  description = "(Required) - Whether the distribution is enabled to accept end user requests for content."
  type        = bool
}

variable "http_version" {
  default     = "http2and3"
  description = "(Optional) - Maximum HTTP version to support on the distribution. Allowed values are http1.1, http2, http2and3 and http3. The default is http2."
  type        = string
}

variable "is_ipv6_enabled" {
  default     = false
  description = "(Optional) - Whether the IPv6 is enabled for the distribution."
  type        = bool
}

variable "logging_config" {
  default     = []
  description = "(Optional) - The logging configuration that controls how logs are written to your distribution (maximum one). AWS provides two versions of access logs for CloudFront: Legacy and v2. This argument configures legacy version standard logs."
  type        = list(object({
    bucket          = string
    include_cookies = optional(bool)
    prefix          = optional(string)
  }))
}

variable "origin" {
  description = "(Required) - The S3 origin for this distribution."
  type        = object({
    connection_attempts = optional(number)
    connection_timeout  = optional(number)
    s3_bucket_name      = string
    origin_id           = string
    origin_path         = optional(string)
  })
}

variable "price_class" {
  default     = null
  description = "(Optional) - Price class for this distribution. One of PriceClass_All, PriceClass_200, PriceClass_100."
  type        = string
}

variable "restrictions" {
  default     = {
    locations         = ["US"]
    restriction_type  = "whitelist"
  }
  description = "(Required) - The restriction configuration for this distribution (maximum one)."
  type        = object({
    locations         = list(string)
    restriction_type  = string
  })
}

variable "staging" {
  default     = false
  description = "(Optional) - A Boolean that indicates whether this is a staging distribution. Defaults to false."
  type        = string
}

variable "tags" {
  default     = null
  description = "(Optional) A map of tags to assign to the resource. If configured with a provider default_tags configuration block present, tags with matching keys will overwrite those defined at the provider-level."
  type        = map(string)
}

variable "viewer_certificate" {
  description = "(Required) - The SSL configuration for this distribution (maximum one)."
  type        = object({
    acm_certificate_arn       = string
    minimum_protocol_version  = string
    ssl_support_method        = string  
  })
}

variable "retain_on_delete" {
  default     = true
  description = "(Optional) - Disables the distribution instead of deleting it when destroying the resource through Terraform. If this is set, the distribution needs to be deleted manually afterwards. Default: false."
  type        = string
}

variable "wait_for_deployment" {
  default     = true
  description = "(Optional) - If enabled, the resource will wait for the distribution status to change from InProgress to Deployed. Setting this tofalse will skip the process. Default: true."
  type        = string
}

#######################################

variable "aws_cloudfront_origin_access_control" {
  description = "Manages an AWS CloudFront Origin Access Control, which is used by CloudFront Distributions with an Amazon S3 bucket as the origin."
  type        = object({
    name                              = string
    description                       = optional(string)
    origin_access_control_origin_type = string
    signing_behavior                  = string
    signing_protocol                  = string
  })
}

variable "aws_wafv2_web_acl" {
  default     = {
    name  = "SamQuickACLEnforcingV2"
    scope = "CLOUDFRONT"
  }
  description = "Creates a WAFv2 Web ACL resource."
  type        = object({
    name  = optional(string)
    scope = string 
  })
}
