variable "app" {
  description = "The short name for the delivery team or ADO."
  type        = string
  validation {
    condition     = contains(["ab2d", "bcda", "dpc", "cdap"], var.app)
    error_message = "Invalid short var.app (application). Must be one of ab2d, bcda, dpc or cdap."
  }
}

variable "env" {
  description = "The application environment (dev, test, sandbox, prod, mgmt)"
  type        = string
  validation {
    condition     = contains(["dev", "test", "sandbox", "prod"], var.env)
    error_message = "Valid value for env is dev, test, sandbox, or prod."
  }
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

variable "ssm_root_map" {
  default     = {}
  description = "Map of SSM parameter hierarchy roots or path prefixes for use in an [SSM Parameters By Path data source](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameters_by_path)"
  type        = map(any)
}
