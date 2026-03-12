variable "app" {
  description = "The short name for the delivery team or ADO."
  type        = string
  validation {
    condition     = contains(["ab2d", "bcda", "cdap", "dpc"], var.app)
    error_message = "Invalid short var.app (application). Must be one of ab2d, bcda, cdap or dpc."
  }
}

variable "env" {
  description = "The solution's environment name."
  type        = string
  validation {
    condition     = one([for x in ["test", "dev", "sandbox", "prod"] : x if can(regex("^${x}$$|^([a-z0-9]+[a-z0-9-])+([^--])-${x}$$", var.env))]) != null
    error_message = "Invalid environment/workspace name. Must end in one of test, dev, sandbox, or prod."
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
