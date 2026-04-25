# OpenTofu for alarm-to-slack function and associated infra

This service sets up the infrastructure for the alarm-to-slack lambda function in upper and lower environments for all applications in var.apps_served.

## Updating the lambda code

The executable for this lambda is in lambda_src. It must pass both pylint and pytest checks.

If you want to see the log messages, you can run pytest with the -s flag.

## Manual deploy

Pass in a backend file when running terraform init. See variables.tf for variables to include. Example:

```bash
AWS_REGION=us-east-1 tofu init -backend-config=../../backends/dpc-dev.s3.tfbackend
AWS_REGION=us-east-1 tofu apply
```

## Automated deploy

This terraform is automatically applied on merge to main by the tf-alarm-to-slack-apply.yml workflow.

<!-- BEGIN_TF_DOCS -->
<!--WARNING: GENERATED CONTENT with terraform-docs, e.g.
     'terraform-docs --config "$(git rev-parse --show-toplevel)/.terraform-docs.yml" .'
     Manually updating sections between TF_DOCS tags may be overwritten.
     See https://terraform-docs.io/user-guide/configuration/ for more information.
-->
## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 5.100.0 |

<!--WARNING: GENERATED CONTENT with terraform-docs, e.g.
     'terraform-docs --config "$(git rev-parse --show-toplevel)/.terraform-docs.yml" .'
     Manually updating sections between TF_DOCS tags may be overwritten.
     See https://terraform-docs.io/user-guide/configuration/ for more information.
-->
## Requirements

No requirements.

<!--WARNING: GENERATED CONTENT with terraform-docs, e.g.
     'terraform-docs --config "$(git rev-parse --show-toplevel)/.terraform-docs.yml" .'
     Manually updating sections between TF_DOCS tags may be overwritten.
     See https://terraform-docs.io/user-guide/configuration/ for more information.
-->
## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_app"></a> [app](#input\_app) | The application name (bcda, cdap) | `string` | n/a | yes |
| <a name="input_env"></a> [env](#input\_env) | The application environment (test, prod) | `string` | n/a | yes |
| <a name="input_apps_served"></a> [apps\_served](#input\_apps\_served) | n/a | `list(string)` | <pre>[<br/>  "bcda",<br/>  "cdap",<br/>  "dpc"<br/>]</pre> | no |

<!--WARNING: GENERATED CONTENT with terraform-docs, e.g.
     'terraform-docs --config "$(git rev-parse --show-toplevel)/.terraform-docs.yml" .'
     Manually updating sections between TF_DOCS tags may be overwritten.
     See https://terraform-docs.io/user-guide/configuration/ for more information.
-->
## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_sns_to_slack_function"></a> [sns\_to\_slack\_function](#module\_sns\_to\_slack\_function) | ../../modules/function | n/a |
| <a name="module_sns_to_slack_queue"></a> [sns\_to\_slack\_queue](#module\_sns\_to\_slack\_queue) | github.com/CMSgov/cdap/terraform/modules/queue | b177921621c97d02dc4a21f830e4532147aa0749 |
| <a name="module_standards"></a> [standards](#module\_standards) | ../../modules/standards | n/a |

<!--WARNING: GENERATED CONTENT with terraform-docs, e.g.
     'terraform-docs --config "$(git rev-parse --show-toplevel)/.terraform-docs.yml" .'
     Manually updating sections between TF_DOCS tags may be overwritten.
     See https://terraform-docs.io/user-guide/configuration/ for more information.
-->
## Resources

| Name | Type |
|------|------|
| [aws_iam_policy_document.sqs_queue_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_ssm_parameters_by_path.slack_webhook_urls](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameters_by_path) | data source |

<!--WARNING: GENERATED CONTENT with terraform-docs, e.g.
     'terraform-docs --config "$(git rev-parse --show-toplevel)/.terraform-docs.yml" .'
     Manually updating sections between TF_DOCS tags may be overwritten.
     See https://terraform-docs.io/user-guide/configuration/ for more information.
-->
## Outputs

| Name | Description |
|------|-------------|
| <a name="output_function_role_arn"></a> [function\_role\_arn](#output\_function\_role\_arn) | n/a |
| <a name="output_sqs_queue_arn"></a> [sqs\_queue\_arn](#output\_sqs\_queue\_arn) | n/a |
| <a name="output_zip_bucket"></a> [zip\_bucket](#output\_zip\_bucket) | n/a |
<!-- END_TF_DOCS -->