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

# -------------------------------------------------------
# Internal endpoint (VPC-only, cmscloud.internal)
# -------------------------------------------------------
variable "enable_internal_endpoint" {
  type        = bool
  default     = false
  description = <<-EOT
    Issue a PCA-backed certificate for the VPC-internal endpoint.
    Domain: <app>-<env>-<service>.internal
    Use for Lambda/ECS-to-ECS calls that do not need Zscaler or public access.
    Route 53 is NOT managed here — DNS for .internal is handled by CMS.
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
    Domain: <app>-<env>-<service>.cmscloud.local
    Route 53 is NOT managed here — DNS for cmscloud.local is handled by CMS.

    -------------------------------------------------------------------------
    CMS DOMAIN REGISTRATION — ACTION REQUIRED AFTER APPLY
    -------------------------------------------------------------------------
    After applying this module, submit a request to CMS to register:
      <app>-<env>-<service>.cmscloud.local
    and point it at the ALB DNS name from the alb module output.
    Use the zscaler_domain output from this module for the request.
    -------------------------------------------------------------------------
  EOT
}

# -------------------------------------------------------
# Public endpoint (*.cms.gov)
# -------------------------------------------------------

variable "public_certificate_versions" {
  type        = set(number)
  default     = [1]
  description = <<-EOT
    Set of active certificate versions. Add a new version number to generate a new
    key and CSR for renewal without deleting the previous version's parameters.
    Example: [1] → initial; [1, 2] → renewal in progress; [2] → old version cleaned up.
  EOT
}

variable "public_domain_name" {
  type        = string
  default     = null
  description = <<-EOT
  Domain name for the public endpoint. Must end in .cms.gov.
      -------------------------------------------------------------------------
      PUBLIC CERTIFICATE PROCESS — ACTION REQUIRED BEFORE CERT IS ACTIVE
      -------------------------------------------------------------------------
      1. Run this module once without public_certificate or public_private_key defined.
      2. Follow output instructions to provide CMS with CSR in a zip file.
      3. Once returned from CMS signed, encrypt the certificate, private key, and chain via SOPS.
      4. Pass the sensitive values via SOPS into public_certificate, public_private_key,
         and public_certificate_chain at module instantiation.
      5. Re-apply — the module imports the cert into ACM automatically.

    EOT
  validation {
    condition     = var.public_domain_name == null || endswith(var.public_domain_name, ".cms.gov")
    error_message = "public_domain_name must end in .cms.gov."
  }
}

# Cert values passed in directly — populated from platform module SOPS outputs at instantiation.
# Set to null to defer cert creation while awaiting CMS issuance.
variable "public_certificate" {
  type        = string
  default     = null
  sensitive   = true
  description = "PEM-encoded CMS-signed public certificate. Include via SOPS if provided by CMS. Set null to defer import while awaiting CMS signing."
}

variable "public_private_key" {
  type        = string
  default     = null
  sensitive   = true
  description = "PEM-encoded private key for the public certificate. Include via SOPS if provided by CMS. Set null to defer."
}

variable "public_certificate_chain" {
  type        = string
  default     = null
  sensitive   = true
  description = "PEM-encoded certificate chain. Optional — include via SOPS if provided by CMS with the signed certificate."
}

variable "pca_ram_resource_share_name" {
  type        = string
  default     = "pace-ca-g1"
  description = "Name of the AWS RAM resource share providing access to the shared Private CA. Required when enable_internal_endpoint or enable_zscaler_endpoint is true."
}
