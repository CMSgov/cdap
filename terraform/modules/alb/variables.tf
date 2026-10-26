# -------------------------------------------------------
# Platform / Core
# -------------------------------------------------------
variable "platform" {
  description = "Object representing the CDAP platform module."
  type = object({
    account_env_suffix = string
    app                = string
    cdap_vpc_name      = string
    env                = string
    primary_region     = object({ name = string })
    private_subnets    = map(object({ id = string }))
    public_subnets     = map(object({ id = string }))
    service            = string
    vpc_cidr           = string
    vpc_id             = string
    security_groups = map(object({
      id   = string
      arn  = string
      name = string
    }))
  })
}

variable "name_override" {
  type        = string
  default     = null
  description = "Override for the ALB name. Defaults to '<var.platform.app>-<var.platform.env>-<var.platform.service>-alb'."
}

# -------------------------------------------------------
# Networking
# -------------------------------------------------------

variable "enable_ingress_from_codebuild_repo" {
  description = "When set, adds an ingress rule allowing that repo's CodeBuild security group access through 443. Null disables this rule entirely."
  type        = string
  default     = null

  validation {
    condition = var.enable_ingress_from_codebuild_repo == null || contains([
      "ab2d",
      "ab2d-website",
      "bcda-app",
      "bcda-ssas-app",
      "bcda-static-site",
      "cdap",
      "dpc-app",
      "dpc-ops",
      "dpc-static-site",
    ], var.enable_ingress_from_codebuild_repo)
    error_message = "Supports connections only from repos with codebuild runners."
  }
}

variable "enable_datadog_synthetics_ingress" {
  type        = bool
  default     = false
  description = <<-EOT
    When true, adds an ingress rule allowing the Datadog synthetics
    private location runner to reach the ALB on HTTPS:443.
    Use in dev/test environments where Datadog private location
    synthetic tests are configured against this ALB.
  EOT
}

variable "subnet_ids" {
  type        = list(string)
  default     = null
  description = <<-EOT
    Override subnet placement. Defaults to platform private subnets for internal ALBs
    and platform public subnets for internet-facing ALBs.
    Only set this if you need non-standard subnet placement.
  EOT
}

variable "security_group_ids" {
  type        = list(string)
  default     = []
  description = "Security group IDs to attach to the ALB."
}

# -------------------------------------------------------
# ALB Visibility
# -------------------------------------------------------
variable "internal" {
  type        = bool
  default     = true
  description = "true = private (internal) ALB; false = public (internet-facing) ALB."
}

#
# Domain Management 
#

variable "private_record_name" {
  type        = string
  default     = null
  description = "Subdomain label for this ALB's record, e.g. 'api-admin'"
}

variable "create_internal_dns_record" {
  type        = bool
  default     = false
  description = <<-EOT
    Create a record reachable by other services in the AWS account.
    Creates `$private_record_name.$env.$app.internal.cms.gov`
  EOT
}

variable "create_zscaler_dns_record" {
  type        = bool
  default     = false
  description = <<-EOT
    Create a record reachable by users in ZScaler network,
    if the hosted zone is registered with Zscaler team.
    Creates `$private_record_name.$env.$app.cmscloud.local`
  EOT

}

# -------------------------------------------------------
# TLS / ACM
# -------------------------------------------------------
variable "acm_certificate_arn" {
  type        = string
  description = <<-EOT
    ARN of the ACM certificate (private CA) for the HTTPS listener.
       Pass either:
         - module.acm.private_cert_arn  for internal/Zscaler endpoints
       Required — this module enforces TLS on all listeners.
  EOT
}

variable "ssl_policy" {
  type        = string
  default     = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  description = "TLS security policy. Default enforces TLS 1.2+ per CMS/FISMA requirements."
}

# -------------------------------------------------------
# Listeners
# -------------------------------------------------------
variable "http_redirect_target_port" {
  description = "Port the plain-HTTP listener redirects to. Must match a key's port in https_listeners."
  type        = number
  default     = 443
}

variable "https_listeners" {
  description = "HTTPS listeners for this ALB. Every entry enforces TLS 1.3 — there is no plain-HTTP option."
  type = map(object({
    port                               = optional(number, 443)
    certificate_arn                    = string
    default_action_type                = optional(string, "fixed-response")
    default_target_group_arn           = optional(string)
    default_fixed_response_status_code = optional(number, 404)
  }))
  default = {}

  validation {
    condition     = length(var.https_listeners) > 0
    error_message = "At least one entry in https_listeners is required — each must include a certificate_arn."
  }
}
