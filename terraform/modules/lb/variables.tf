# -------------------------------------------------------
# Platform / Core
# -------------------------------------------------------
variable "platform" {
  description = "Object representing the CDAP platform module."
  type = object({
    account_env_suffix = string
    app                = string
    cdap_env           = string
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


variable "create_alb" {
  description = "Create the Application Load Balancer."
  type        = bool
  default     = true
}

variable "create_nlb" {
  description = "Create the Network Load Balancer."
  type        = bool
  default     = false
}

variable "nlb_mode" {
  description = <<-EOT
    What the NLB forwards to, when create_nlb is true:
      "front_alb" - module owns the NLB listener + a target_type=alb target
                    group pointed at this module's own ALB. Today's only
                    supported mode; used for PrivateLink in front of an
                    existing ALB.
      "direct"    - module creates only the bare NLB + its security group.
                    No listener, no target group. Reserved for a future
                    ecs-service "enable_nlb_integration" that creates its
                    own listener(s)/target group(s) against this NLB's
                    ARN, for direct-to-Fargate / mTLS-passthrough traffic.
  EOT
  type        = string
  default     = "front_alb"

  validation {
    condition     = contains(["front_alb", "direct"], var.nlb_mode)
    error_message = "nlb_mode must be \"front_alb\" or \"direct\"."
  }
}

variable "enable_privatelink" {
  description = "Create an internal NLB + VPC Endpoint Service for cross-VPC PrivateLink access. Requires create_nlb = true."
  type        = bool
  default     = false
}

variable "privatelink_target_port" {
  description = "Port the PrivateLink NLB listens on. Only used when nlb_mode = \"front_alb\"; must match a port in var.https_listeners. Ignored in \"direct\" mode."
  type        = number
  default     = 443
}

variable "privatelink_health_check_path" {
  description = "Path the NLB target group health-checks on the ALB. Must return 2xx/3xx — not the default 404 fixed-response."
  type        = string
  default     = "/healthz"
}

variable "privatelink_private_dns_name" {
  description = "Verified domain name for this PrivateLink service. Leave null unless public-DNS verification is confirmed possible for this domain."
  type        = string
  default     = null
}

variable "nlb_security_group_ids" {
  description = "Existing security group IDs for the NLB. Leave empty to let the module manage one."
  type        = list(string)
  default     = []
}

variable "enable_deletion_protection" {
  description = "Override deletion protection on the ALB. Leave null to default to true for external (!internal) ALBs and false for internal ones."
  type        = bool
  default     = null
}
