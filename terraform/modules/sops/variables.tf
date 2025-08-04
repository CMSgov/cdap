variable "platform" {
  description = "Object that describes standardized platform values."
  type        = any
}

variable "sopsw_values_file_extension" {
  default     = "sopsw.yaml"
  description = "Override. File extension of the wrapped sops 'sopsw' values file."
  type        = string
}

variable "sopsw_values_dir" {
  default     = null
  description = "Override. Path to the root module's directory where the wrapped sops 'sopsw' values files directory. Defaults to `./values/` within the root module."
  type        = string
}

variable "sopsw_parent_yaml_file" {
  default     = null
  description = "Override. With `var.sopsw_values_file_extension`, specifies the wrapped, sops 'sopsw' values file base name. Defaults to `$${local.parent_env}.$${var.sopsw_values_file_extension}`, e.g. `prod.sopsw.yaml`."
  type        = string
}

variable "create_local_sops_wrapper" {
  default     = true
  description = "Specify whether to create the script for localling editing the wrapped, sops 'sopsw' values file."
  type        = string
}
