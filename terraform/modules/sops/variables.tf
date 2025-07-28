variable "platform" {
  description = "Object that describes standardized platform values."
  type        = any
}

variable "sops_values_dir" {
  default     = null
  description = "Override. Path to the root module's directory where secured, sops.yaml files are stored. Defaults to `./values/`."
  type        = string
}

variable "sops_parent_yaml_file" {
  default     = null
  description = "Override. The specific sops.yaml file to be used. Defaults to `$app-$env.sops.yaml`."
  type        = string
}

variable "create_local_sopsw_file" {
  default     = true
  description = "Specify whether a local sopsw file should be created for locally applying adjustments to sops files."
  type        = string
}
