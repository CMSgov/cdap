This service instantiates the necessary API keys and Application keys per application running Terraform or leveraging Datadog in Github Actions. 

When the creator of that administrator's Datadog account is terminated, an admin user must

0) decrypt the sops files per config instructions: `bin/sopsw -e values/prod.sopsw.yaml`
1) generate a new application key via:
https://app.ddog-gov.com/organization-settings/application-keys. 
2) write the application key in the sops file and save 
3) repeat these instructions but using `test.sopsw.yaml`

If SOPs cannot be leveraged, the administrator can write the value directly into the SSM parameter in each account at the path `/dasgapi/sensitive/datadog/init_application_key`.

The API key will not need to be regenerated for operations continue, though you may wish to rotate that key as well via `/dasgapi/sensitive/datadog/init_api_key`.
<!-- BEGIN_TF_DOCS -->
<!--WARNING: GENERATED CONTENT with terraform-docs, e.g.
     'terraform-docs --config "$(git rev-parse --show-toplevel)/.terraform-docs.yml" .'
     Manually updating sections between TF_DOCS tags may be overwritten.
     See https://terraform-docs.io/user-guide/configuration/ for more information.
-->
## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.50.0 |

<!--WARNING: GENERATED CONTENT with terraform-docs, e.g.
     'terraform-docs --config "$(git rev-parse --show-toplevel)/.terraform-docs.yml" .'
     Manually updating sections between TF_DOCS tags may be overwritten.
     See https://terraform-docs.io/user-guide/configuration/ for more information.
-->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~>6.0 |
| <a name="requirement_datadog"></a> [datadog](#requirement\_datadog) | ~>4.4 |

<!--WARNING: GENERATED CONTENT with terraform-docs, e.g.
     'terraform-docs --config "$(git rev-parse --show-toplevel)/.terraform-docs.yml" .'
     Manually updating sections between TF_DOCS tags may be overwritten.
     See https://terraform-docs.io/user-guide/configuration/ for more information.
-->
## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_app"></a> [app](#input\_app) | ["ab2d", "bcda", "dpc", "cdap", "bb"] The application name. | `string` | n/a | yes |
| <a name="input_env"></a> [env](#input\_env) | The application environment (dev, test, sandbox, prod) | `string` | n/a | yes |

<!--WARNING: GENERATED CONTENT with terraform-docs, e.g.
     'terraform-docs --config "$(git rev-parse --show-toplevel)/.terraform-docs.yml" .'
     Manually updating sections between TF_DOCS tags may be overwritten.
     See https://terraform-docs.io/user-guide/configuration/ for more information.
-->
## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_additional_datadog_api_key"></a> [additional\_datadog\_api\_key](#module\_additional\_datadog\_api\_key) | ../../modules/datadog_api_key | n/a |
| <a name="module_additional_datadog_application_key"></a> [additional\_datadog\_application\_key](#module\_additional\_datadog\_application\_key) | ../../modules/datadog_application_key | n/a |
| <a name="module_datadog_api_key"></a> [datadog\_api\_key](#module\_datadog\_api\_key) | ../../modules/datadog_api_key | n/a |
| <a name="module_datadog_application_key"></a> [datadog\_application\_key](#module\_datadog\_application\_key) | ../../modules/datadog_application_key | n/a |
| <a name="module_standards"></a> [standards](#module\_standards) | ../../modules/standards | n/a |

<!--WARNING: GENERATED CONTENT with terraform-docs, e.g.
     'terraform-docs --config "$(git rev-parse --show-toplevel)/.terraform-docs.yml" .'
     Manually updating sections between TF_DOCS tags may be overwritten.
     See https://terraform-docs.io/user-guide/configuration/ for more information.
-->
## Resources

| Name | Type |
|------|------|
| [aws_secretsmanager_secret.datadog_api_key](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret) | resource |
| [aws_secretsmanager_secret.datadog_application_key](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret) | resource |
| [aws_secretsmanager_secret_policy.datadog_api_key](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_policy) | resource |
| [aws_secretsmanager_secret_policy.datadog_application_key](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_policy) | resource |
| [aws_secretsmanager_secret_version.datadog_api_key](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_version) | resource |
| [aws_secretsmanager_secret_version.datadog_application_key](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_version) | resource |
| [aws_kms_alias.shares](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/kms_alias) | data source |

<!--WARNING: GENERATED CONTENT with terraform-docs, e.g.
     'terraform-docs --config "$(git rev-parse --show-toplevel)/.terraform-docs.yml" .'
     Manually updating sections between TF_DOCS tags may be overwritten.
     See https://terraform-docs.io/user-guide/configuration/ for more information.
-->
## Outputs

No outputs.
<!-- END_TF_DOCS -->