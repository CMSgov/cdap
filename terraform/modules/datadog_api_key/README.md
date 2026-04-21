This module generates a single API key and is generated for specific service use. These keys are leveraged by services to push data to Datadog.

<!-- BEGIN_TF_DOCS -->
<!--WARNING: GENERATED CONTENT with terraform-docs, e.g.
     'terraform-docs --config "$(git rev-parse --show-toplevel)/.terraform-docs.yml" .'
     Manually updating sections between TF_DOCS tags may be overwritten.
     See https://terraform-docs.io/user-guide/configuration/ for more information.
-->
## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | ~>5 |
| <a name="provider_datadog"></a> [datadog](#provider\_datadog) | ~>4.4 |

<!--WARNING: GENERATED CONTENT with terraform-docs, e.g.
     'terraform-docs --config "$(git rev-parse --show-toplevel)/.terraform-docs.yml" .'
     Manually updating sections between TF_DOCS tags may be overwritten.
     See https://terraform-docs.io/user-guide/configuration/ for more information.
-->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~>5 |
| <a name="requirement_datadog"></a> [datadog](#requirement\_datadog) | ~>4.4 |

<!--WARNING: GENERATED CONTENT with terraform-docs, e.g.
     'terraform-docs --config "$(git rev-parse --show-toplevel)/.terraform-docs.yml" .'
     Manually updating sections between TF_DOCS tags may be overwritten.
     See https://terraform-docs.io/user-guide/configuration/ for more information.
-->
## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_app"></a> [app](#input\_app) | ["ab2d", "bcda", "dpc", "cdap"] The application name. | `string` | n/a | yes |
| <a name="input_env"></a> [env](#input\_env) | ["dev", "test", "sandbox", "prod", "non-prod"] The environment that leverages this key. | `string` | n/a | yes |
| <a name="input_used_for"></a> [used\_for](#input\_used\_for) | ["cicd" or "agents"]The suffix for this API key. API usage is limited to 50 keys in the Datadog organization. | `string` | n/a | yes |

<!--WARNING: GENERATED CONTENT with terraform-docs, e.g.
     'terraform-docs --config "$(git rev-parse --show-toplevel)/.terraform-docs.yml" .'
     Manually updating sections between TF_DOCS tags may be overwritten.
     See https://terraform-docs.io/user-guide/configuration/ for more information.
-->
## Modules

No modules.

<!--WARNING: GENERATED CONTENT with terraform-docs, e.g.
     'terraform-docs --config "$(git rev-parse --show-toplevel)/.terraform-docs.yml" .'
     Manually updating sections between TF_DOCS tags may be overwritten.
     See https://terraform-docs.io/user-guide/configuration/ for more information.
-->
## Resources

| Name | Type |
|------|------|
| [aws_ssm_parameter.datadog_api_key](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [datadog_api_key.this](https://registry.terraform.io/providers/DataDog/datadog/latest/docs/resources/api_key) | resource |
| [aws_kms_alias.primary](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/kms_alias) | data source |

<!--WARNING: GENERATED CONTENT with terraform-docs, e.g.
     'terraform-docs --config "$(git rev-parse --show-toplevel)/.terraform-docs.yml" .'
     Manually updating sections between TF_DOCS tags may be overwritten.
     See https://terraform-docs.io/user-guide/configuration/ for more information.
-->
## Outputs

| Name | Description |
|------|-------------|
| <a name="output_api_key_id"></a> [api\_key\_id](#output\_api\_key\_id) | n/a |
| <a name="output_ssm_parameter_name"></a> [ssm\_parameter\_name](#output\_ssm\_parameter\_name) | The SSM path storing the generated API key. |
<!-- END_TF_DOCS -->