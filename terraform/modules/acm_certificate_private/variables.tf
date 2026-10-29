variable "platform" {
  description = "Object representing the CDAP platform module."
  type = object({
    app            = string
    env            = string
    primary_region = object({ name = string })
    service        = string
    kms_alias_primary = object({
      target_key_arn = string
    })
  })
}

variable "domain_name" {
  description = "Subdomain string. If left empty, defaults to platform service name."
  default     = null
  type        = string
}

# -------------------------------------------------------
# Internal endpoint (VPC-only, internal.cms.gov)
# -------------------------------------------------------
variable "enable_internal_endpoint" {
  type        = bool
  default     = false
  description = <<-EOT
    Issue a PCA-backed certificate for the VPC-internal endpoint.
    Domain: <service>.<env>.<app>.internal.cms.gov
    Use for Lambda/ECS-to-ECS calls that do not need Zscaler or public access.
    Route 53 is NOT managed here.
  EOT
}

# -------------------------------------------------------
# Zscaler endpoint (cmscloud.local)
# -------------------------------------------------------
variable "enable_zscaler_endpoint" {
  type        = bool
  default     = false
  description = <<-EOT
    Issue a PCA-backed certificate for the Zscaler-accessible endpoint.
    Domain: <service>.<env>.<app>.cmscloud.local
    Route 53 is NOT managed here — DNS for cmscloud.local is handled by CMS.

    -------------------------------------------------------------------------
    CMS DOMAIN REGISTRATION — ACTION REQUIRED AFTER APPLY
    -------------------------------------------------------------------------
    After applying this module, submit a request to CMS to register:
      <service>.<env>.<app>.cmscloud.local
    and point it at the ALB DNS name from the alb module output.
    Use the zscaler_domain output from this module for the request.
    -------------------------------------------------------------------------
  EOT
}

# -------------------------------------------------------
# mTLS sidecar
# -------------------------------------------------------

variable "enable_mtls_sidecar" {
  type        = bool
  default     = false
  description = <<-EOT
    Issue a PCA-backed certificate for mTLS between an NLB and the sidecar container.
    This certificate is NOT accessed by developers via Zscaler — it is used internally
    between the ALB and ECS sidecar only.
    Domain: <service>.<env>.<app>.internal.cms.gov (same as internal endpoint).
  EOT
}

variable "pca_ram_resource_share_name" {
  type        = string
  default     = "pace-ca-g1"
  description = "Name of the AWS RAM resource share providing access to the shared Private CA. Required when enable_internal_endpoint or enable_zscaler_endpoint is true."
}
