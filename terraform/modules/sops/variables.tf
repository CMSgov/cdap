variable "platform" {
  description = "The input for higher-order platform-provided resources, such as the CDAP `platform` module, to encourage standards adoption."
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
