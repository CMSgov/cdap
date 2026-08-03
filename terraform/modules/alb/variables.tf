# -------------------------------------------------------
# Platform / Core
# -------------------------------------------------------
variable "platform" {
  description = "Object representing the CDAP platform module."
  type = object({
    app             = string
    env             = string
    primary_region  = object({ name = string })
    private_subnets = map(object({ id = string }))
    public_subnets  = map(object({ id = string }))
    service         = string
    vpc_id          = string
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

variable "enable_zscaler_ingress" {
  type        = bool
  default     = false
  description = <<-EOT
    When true, adds an ingress rule allowing the Zscaler private App
    Connector to reach the ALB on HTTPS:443.
    Enable this when the ALB is registered in cmscloud.local DNS and
    accessed by developers via Zscaler.
    Should be set alongside enable_zscaler_endpoint = true on the
    acm_certificate module.
  EOT
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

# -------------------------------------------------------
# TLS / ACM
# -------------------------------------------------------
variable "acm_certificate_arn" {
  type        = string
  description = <<-EOT
    ARN of the ACM certificate (public or private CA) for the HTTPS listener.
       Pass either:
         - module.acm.private_cert_arn  for internal/Zscaler endpoints
         - module.acm.public_cert_arn   for public *.<app>.cms.gov endpoints
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
variable "enable_http_redirect" {
  type        = bool
  default     = true
  description = "When true, adds an HTTP:80 listener that redirects all traffic to HTTPS:443."
}

variable "extra_listeners" {
  description = "Additional HTTPS listeners beyond the default 443"
  type = map(object({
    port                = number
    acm_certificate_arn = optional(string)
    ssl_policy          = optional(string)
  }))
  default = {}
}
