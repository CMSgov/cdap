variable "create_local_sops_wrapper" {
  default     = false
  description = "When `true`, creates sops wrapper file at `bin/sopsw`."
  type        = bool
}

variable "env" {
  description = "The application environment (test, prod)"
  type        = string
  validation {
    condition     = contains(["test", "prod"], var.env)
    error_message = "Valid value for env is test or prod."
  }
}
