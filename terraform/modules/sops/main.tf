terraform {
  required_providers {
    sops = {
      source  = "carlpett/sops"
      version = "1.2.0"
    }
    #TODO specify the other provider versions here
  }
}

locals {
  # Platform Provided Local Variables
  app              = var.platform["app"]
  account_id       = var.platform["account_id"]
  is_ephemeral_env = var.platform["is_ephemeral_env"]
  env              = var.platform["env"]
  parent_env       = var.platform["parent_env"]
  env_key_alias_id = var.platform["kms_alias_primary"]["id"]

  # Local Variables with Input Variable Overrides
  sops_values_dir            = coalesce(var.sops_values_dir, "${path.root}/values")
  sops_parent_yaml_file      = coalesce(var.sops_parent_yaml_file, "${local.parent_env}.sops.yaml")
  sops_parent_yaml_file_path = "${local.sops_values_dir}/${local.parent_env}.sops.yaml"

  # Internal and Other Derived Variables
  template_var_regex      = "/\\$\\{{0,1}%s\\}{0,1}/"
  raw_sops_parent_yaml    = file(local.sops_parent_yaml_file_path)
  valid_sops_parent_yaml  = data.external.valid_sops_yaml.result.valid_sops
  enc_parent_data         = yamldecode(local.valid_sops_parent_yaml)
  sops_nonsensitive_regex = local.enc_parent_data.sops.unencrypted_regex

  decrypted_parent_data = yamldecode(data.sops_external.this.raw)
  parent_ssm_config = {
    for key, val in nonsensitive(local.decrypted_parent_data) : key => {
      str_val      = tostring(val)
      is_sensitive = length(regexall(local.sops_nonsensitive_regex, key)) == 0
      source       = basename(local.sops_parent_yaml_file)
    } if lower(tostring(val)) != "undefined"
  }

  ephemeral_yaml_file = "${local.sops_values_dir}/ephemeral.yaml"
  ephemeral_yaml_raw  = fileexists(local.ephemeral_yaml_file) ? file(local.ephemeral_yaml_file) : "{\"copy\": [], \"value\": {}}"
  ephemeral_data      = yamldecode(local.ephemeral_yaml_raw)
  ephemeral_to_copy = [
    for key in keys(local.parent_ssm_config)
    # Using anytrue+strcontains to enable recursive copying from the parent environment, e.g.
    # client_certificates hierarchy
    : key if anytrue([for copy_key in lookup(local.ephemeral_data, "copy", {}) : strcontains(key, copy_key)])
  ]
  ephemeral_vals = {
    for key, val in lookup(local.ephemeral_data, "values", {})
    : key => {
      str_val      = tostring(val)
      is_sensitive = false
      source       = basename(local.ephemeral_yaml_file)
    } if lower(tostring(val)) != "undefined"
  }

  untemplated_env_config = local.is_ephemeral_env ? merge(
    # First, copy the values specified in ephemeral "copy" from the parent env's configuration
    {
      for k, v in local.parent_ssm_config
      : k => v if contains(local.ephemeral_to_copy, k)
    },
    # Then, take any ephemeral default values. These take precedence in case a parameter was
    # erroneously specified for copying
    local.ephemeral_vals
  ) : local.parent_ssm_config
  env_config = {
    for k, v in local.untemplated_env_config
    : "${replace(k, format(local.template_var_regex, "env"), local.env)}" => {
      str_val      = replace(v.str_val, format(local.template_var_regex, "env"), local.env)
      is_sensitive = v.is_sensitive
      source       = v.source
    }
  }
}

data "external" "valid_sops_yaml" {
  # sops (not sopsw, our custom wrapper) cannot decrypt the YAML until the KMS key ARNs include the
  # Account ID and the sops metadata block includes valid "lastmodified" and "mac" properties. We
  # need to use sopsw's "-c/--cat" function to construct a valid sops file so that it can be
  # consumed by the sops provider
  program = [
    "bash",
    "-c",
    # Allows us to pipe to yq so that sopsw does not need to emit JSON to work with this external
    # data source
    <<-EOF
    ${path.module}/bin/sopsw -c ${local.sops_parent_yaml_file_path} | yq -o=json '{"valid_sops": (. | tostring)}'
    EOF
  ]
}

data "sops_external" "this" {
  source     = local.valid_sops_parent_yaml
  input_type = "yaml"
}

#NOTE: While this is technically unused, it does provide validation of KMS Key existence
data "aws_kms_key" "sops_key" {
  key_id = local.env_key_alias_id
}

resource "aws_ssm_parameter" "this" {
  for_each = local.env_config

  name           = each.key
  tier           = "Intelligent-Tiering"
  value          = each.value.is_sensitive ? each.value.str_val : null
  insecure_value = each.value.is_sensitive ? null : try(nonsensitive(each.value.str_val), each.value.str_val)
  type           = each.value.is_sensitive ? "SecureString" : "String"
  key_id         = each.value.is_sensitive ? local.env_key_alias_id : null

  tags = {
    source_file    = each.value.source
    managed_config = true
  }
}

resource "local_file" "sopsw" {
  count = var.create_local_sopsw_file ? 1 : 0
  content = file("${path.module}/bin/sopsw")
  filename = "${path.root}/bin/sopsw"
}

output "sopsw" {
  value = var.create_local_sopsw_file ? "${local_file.sopsw[0].filename} ${local.parent_env}" : null
}
