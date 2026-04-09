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
    service         = string
    vpc_id          = string
  })
}

variable "name_override" {
  type        = string
  default     = null
  description = "Override for the ALB name. Defaults to '${var.platform.app}-${var.platform.env}-${var.platform.service}-alb'."
}

# -------------------------------------------------------
# Networking
# -------------------------------------------------------
variable "subnet_ids" {
  type        = list(string)
  default     = null
  description = "Subnet IDs to place the ALB in. Defaults to the platform's private subnets."
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
  description = "ARN of the ACM certificate (public or private CA) for the HTTPS listener."
}

variable "ssl_policy" {
  type        = string
  default     = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  description = "TLS security policy. Default enforces TLS 1.2+ per CMS/FISMA requirements."
}

# -------------------------------------------------------
# HTTP Redirect
# -------------------------------------------------------
variable "enable_http_redirect" {
  type        = bool
  default     = true
  description = "When true, adds an HTTP:80 listener that redirects all traffic to HTTPS:443."
}
