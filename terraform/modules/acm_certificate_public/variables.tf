
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
  type        = map(string)
  default     = {}
  sensitive   = true
  description = "Map of version to PEM-encoded CMS-signed certificate."
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
