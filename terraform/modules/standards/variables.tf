variable "app" {
  description = "The short name for the delivery team or ADO."
  type        = string
  validation {
    condition     = contains(["ab2d", "bcda", "cdap", "dpc"], var.app)
    error_message = "Invalid short var.app (application). Must be one of ab2d, bcda, cdap, or dpc."
  }
}

variable "env" {
  description = "The solution's environment name."
  type        = string
}

variable "service" {
  description = "Service _or_ terraservice name."
  type        = string
}

variable "additional_tags" {
  default     = {}
  description = "Additional tags to merge into final default_tags output"
  type        = map(string)
}

variable "root_module" {
  description = "The full URL to the terraform module root at issue for this infrastructure"
  type        = string
}
