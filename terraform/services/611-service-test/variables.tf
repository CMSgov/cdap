variable "env" {
  description = "The application environment (test, prod)"
  type        = string
  validation {
    condition     = contains(["test", "prod"], var.env)
    error_message = "Valid value for env is test, prod."
  }
}

variable "ecs_enabled" {
  description = "Override for ecs.enabled — used by workflow to spin down ephemeral services on merge"
  type        = bool
  default     = null # null means "read from config" so default is what's in config and local dev can use variables
}
