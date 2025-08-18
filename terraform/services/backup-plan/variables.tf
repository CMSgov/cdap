variable "vault_name" {
  description = "Name of the primary backup vault"
  type        = string
  default     = "CMS-CDAP-MANAGED_VAULT"
}

variable "env" {
  description = "The application environment (test, prod)"
  type        = string
  validation {
    condition     = contains(["test", "prod"], var.env)
    error_message = "Valid value for env is test or prod."
  }
}
