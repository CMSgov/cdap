Establishes configuration that is used for the entire DASG APIs Datadog Organization.

<!-- BEGIN_TF_DOCS -->
<!--WARNING: GENERATED CONTENT with terraform-docs, e.g.
     'terraform-docs --config "$(git rev-parse --show-toplevel)/.terraform-docs.yml" .'
     Manually updating sections between TF_DOCS tags may be overwritten.
     See https://terraform-docs.io/user-guide/configuration/ for more information.
-->
## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_datadog"></a> [datadog](#provider\_datadog) | ~>4.4 |

<!--WARNING: GENERATED CONTENT with terraform-docs, e.g.
     'terraform-docs --config "$(git rev-parse --show-toplevel)/.terraform-docs.yml" .'
     Manually updating sections between TF_DOCS tags may be overwritten.
     See https://terraform-docs.io/user-guide/configuration/ for more information.
-->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~>6.0 |
| <a name="requirement_datadog"></a> [datadog](#requirement\_datadog) | ~>4.4 |

<!--WARNING: GENERATED CONTENT with terraform-docs, e.g.
     'terraform-docs --config "$(git rev-parse --show-toplevel)/.terraform-docs.yml" .'
     Manually updating sections between TF_DOCS tags may be overwritten.
     See https://terraform-docs.io/user-guide/configuration/ for more information.
-->
## Inputs

No inputs.

<!--WARNING: GENERATED CONTENT with terraform-docs, e.g.
     'terraform-docs --config "$(git rev-parse --show-toplevel)/.terraform-docs.yml" .'
     Manually updating sections between TF_DOCS tags may be overwritten.
     See https://terraform-docs.io/user-guide/configuration/ for more information.
-->
## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_standards"></a> [standards](#module\_standards) | ../../modules/standards | n/a |

<!--WARNING: GENERATED CONTENT with terraform-docs, e.g.
     'terraform-docs --config "$(git rev-parse --show-toplevel)/.terraform-docs.yml" .'
     Manually updating sections between TF_DOCS tags may be overwritten.
     See https://terraform-docs.io/user-guide/configuration/ for more information.
-->
## Resources

| Name | Type |
| ---- | ---- |
| [datadog_monitor_config_policy.env_tag](https://registry.terraform.io/providers/DataDog/datadog/latest/docs/resources/monitor_config_policy) | resource |
| [datadog_sensitive_data_scanner_group.main](https://registry.terraform.io/providers/DataDog/datadog/latest/docs/resources/sensitive_data_scanner_group) | resource |
| [datadog_sensitive_data_scanner_rule.bb_encrypted_values](https://registry.terraform.io/providers/DataDog/datadog/latest/docs/resources/sensitive_data_scanner_rule) | resource |
| [datadog_sensitive_data_scanner_rule.dot_access_token](https://registry.terraform.io/providers/DataDog/datadog/latest/docs/resources/sensitive_data_scanner_rule) | resource |
| [datadog_sensitive_data_scanner_rule.dot_client_id](https://registry.terraform.io/providers/DataDog/datadog/latest/docs/resources/sensitive_data_scanner_rule) | resource |
| [datadog_sensitive_data_scanner_rule.dot_client_secret](https://registry.terraform.io/providers/DataDog/datadog/latest/docs/resources/sensitive_data_scanner_rule) | resource |
| [datadog_sensitive_data_scanner_rule.mbi](https://registry.terraform.io/providers/DataDog/datadog/latest/docs/resources/sensitive_data_scanner_rule) | resource |
| [datadog_sensitive_data_scanner_rule.selected_standard_rules](https://registry.terraform.io/providers/DataDog/datadog/latest/docs/resources/sensitive_data_scanner_rule) | resource |
| [datadog_sensitive_data_scanner_standard_pattern.selected_standard_rules](https://registry.terraform.io/providers/DataDog/datadog/latest/docs/data-sources/sensitive_data_scanner_standard_pattern) | data source |

<!--WARNING: GENERATED CONTENT with terraform-docs, e.g.
     'terraform-docs --config "$(git rev-parse --show-toplevel)/.terraform-docs.yml" .'
     Manually updating sections between TF_DOCS tags may be overwritten.
     See https://terraform-docs.io/user-guide/configuration/ for more information.
-->
## Outputs

No outputs.
<!-- END_TF_DOCS -->