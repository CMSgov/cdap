locals {
  # Platform Provided Local Variables
  is_ephemeral_env = var.platform.is_ephemeral_env
  env              = var.platform.env
  parent_env       = var.platform.parent_env
  env_key_arn      = var.platform.kms_alias_primary.id

  # Local Variables with Input Variable Overrides
  sopsw_values_dir            = coalesce(var.sopsw_values_dir, "${path.root}/values")
  sopsw_parent_yaml_file      = coalesce(var.sopsw_parent_yaml_file, "${local.parent_env}.${var.sopsw_values_file_extension}")
  sopsw_parent_yaml_file_path = "${local.sopsw_values_dir}/${local.sopsw_parent_yaml_file}"

  # Internal and Other Derived Variables
  template_var_regex       = "/\\$\\{{0,1}%s\\}{0,1}/"
  raw_sopsw_parent_yaml    = file(local.sopsw_parent_yaml_file_path)
  enc_parent_data          = yamldecode(local.raw_sopsw_parent_yaml)
  sopsw_nonsensitive_regex = local.enc_parent_data.sops.unencrypted_regex

  # decrypted_parent_data = yamldecode(data.sopsw_external.this.raw)
  decrypted_parent_data = yamldecode(data.external.decrypted_sops.result.decrypted_sops)
  parent_ssm_config = {
    for key, val in nonsensitive(local.decrypted_parent_data) : key => {
      str_val      = tostring(val)
      is_sensitive = length(regexall(local.sopsw_nonsensitive_regex, key)) == 0
      source       = basename(local.sopsw_parent_yaml_file)
    } if lower(tostring(val)) != "undefined"
  }

  ephemeral_yaml_file = "${local.sopsw_values_dir}/ephemeral.yaml"
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
    : replace(k, format(local.template_var_regex, "env"), local.env) => {
      str_val      = replace(v.str_val, format(local.template_var_regex, "env"), local.env)
      is_sensitive = v.is_sensitive
      source       = v.source
    }
  }
}

data "external" "decrypted_sops" {
  # sops (not sopsw, our custom wrapper) cannot decrypt the YAML until the KMS key ARNs include the
  # Account ID and the sops metadata block includes valid "lastmodified" and "mac" properties. We
  # need to instead pass the file through sopsw's "-d/--decrypt" function
  program = [
    "bash",
    "-c",
    # Allows us to pipe to yq so that sopsw does not need to emit JSON to work with this external
    # data source
    <<-EOF
    ${path.module}/bin/sopsw -d ${local.sopsw_parent_yaml_file_path} | yq -o=json '{"decrypted_sops": (. | tostring)}'
    EOF
  ]
}

resource "aws_ssm_parameter" "this" {
  for_each = local.env_config

  name           = each.key
  tier           = "Intelligent-Tiering"
  value          = each.value.is_sensitive ? each.value.str_val : null
  insecure_value = each.value.is_sensitive ? null : try(nonsensitive(each.value.str_val), each.value.str_val)
  type           = each.value.is_sensitive ? "SecureString" : "String"
  key_id         = each.value.is_sensitive ? local.env_key_arn : null

  tags = {
    source_file    = each.value.source
    managed_config = true
  }
}

resource "local_file" "sopsw" {
  count    = var.create_local_sopsw_file ? 1 : 0
  content  = file("${path.module}/bin/sopsw")
  filename = "${path.root}/bin/sopsw"
}
