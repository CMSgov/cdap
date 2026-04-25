# Terraform module for function resources

This is a generic module for creating lambda function resources in CMS Cloud. Use it in terraform services where a lambda function is needed.

Note that a dummy function is included to allow for initialization without defined source code. It is meant to be replaced once the function has been created.
Function logic can be deployed separately via GitHub actions or can be updated by re-applying Terraform with source_dir set.  

<!-- BEGIN_TF_DOCS -->
<!--WARNING: GENERATED CONTENT with terraform-docs, e.g.
     'terraform-docs --config "$(git rev-parse --show-toplevel)/.terraform-docs.yml" .'
     Manually updating sections between TF_DOCS tags may be overwritten.
     See https://terraform-docs.io/user-guide/configuration/ for more information.
-->
## Providers

| Name | Version |
|------|---------|
| <a name="provider_archive"></a> [archive](#provider\_archive) | n/a |
| <a name="provider_aws"></a> [aws](#provider\_aws) | n/a |

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
| <a name="input_app"></a> [app](#input\_app) | The application name (ab2d, bcda, cdap dpc) | `string` | n/a | yes |
| <a name="input_description"></a> [description](#input\_description) | Description of the lambda function | `string` | n/a | yes |
| <a name="input_env"></a> [env](#input\_env) | The application environment (dev, test, sandbox, prod) | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Name of the lambda function | `string` | n/a | yes |
| <a name="input_architecture"></a> [architecture](#input\_architecture) | Lambda function CPU architecture. Use arm64 for Graviton (better price/performance for most workloads). | `string` | `"x86_64"` | no |
| <a name="input_create_function_zip"></a> [create\_function\_zip](#input\_create\_function\_zip) | Upload a dummy zip to initialize the S3 bucket on first apply.<br/>Has no effect and should not be set to true when source\_dir is provided,<br/>as the module will manage the zip and upload automatically. | `bool` | `false` | no |
| <a name="input_environment_variables"></a> [environment\_variables](#input\_environment\_variables) | Map of environment variables for the function | `map(string)` | `{}` | no |
| <a name="input_extra_kms_key_arns"></a> [extra\_kms\_key\_arns](#input\_extra\_kms\_key\_arns) | Optional list of additional KMS key ARNs the Lambda can use | `list(string)` | `[]` | no |
| <a name="input_function_role_inline_policies"></a> [function\_role\_inline\_policies](#input\_function\_role\_inline\_policies) | Inline policies (in JSON) for the function IAM role | `map(string)` | `{}` | no |
| <a name="input_github_actions_repos"></a> [github\_actions\_repos](#input\_github\_actions\_repos) | Used for integration tests and, when source\_dir is null,<br/>for CI/CD workflows that upload the function zip.<br/>Format: "repo:CMSgov/<repo-name>:*" or a more specific ref pattern.<br/>Defaults to empty — no GitHub Actions access unless explicitly granted. | `list(string)` | `[]` | no |
| <a name="input_handler"></a> [handler](#input\_handler) | Lambda function handler | `string` | `"function_handler"` | no |
| <a name="input_layer_arns"></a> [layer\_arns](#input\_layer\_arns) | Optional list of layer arns | `list(string)` | `[]` | no |
| <a name="input_log_retention_days"></a> [log\_retention\_days](#input\_log\_retention\_days) | Number of days to retain Lambda function logs in CloudWatch. If null, no retention policy is set and retention is managed externally (e.g., via cdap/scripts/set\_log\_retention/). | `number` | `180` | no |
| <a name="input_memory_size"></a> [memory\_size](#input\_memory\_size) | Lambda function memory size | `number` | `null` | no |
| <a name="input_runtime"></a> [runtime](#input\_runtime) | Lambda function runtime | `string` | `"python3.11"` | no |
| <a name="input_schedule_expression"></a> [schedule\_expression](#input\_schedule\_expression) | Cron or rate expression for a scheduled function | `string` | `""` | no |
| <a name="input_source_code_version"></a> [source\_code\_version](#input\_source\_code\_version) | Optional S3 object version of function.zip uploaded to module's zip\_bucket by external sources. | `string` | `null` | no |
| <a name="input_source_dir"></a> [source\_dir](#input\_source\_dir) | Path to the Lambda source directory to zip and upload. If set, the module manages zipping and deployment. If null, an external process (or dummy zip) is used. | `string` | `null` | no |
| <a name="input_source_dir_excludes"></a> [source\_dir\_excludes](#input\_source\_dir\_excludes) | List of glob (**/*) patterns to exclude when zipping the source directory. | `list(string)` | `[]` | no |
| <a name="input_ssm_parameter_paths"></a> [ssm\_parameter\_paths](#input\_ssm\_parameter\_paths) | List of SSM parameter ARNs or path patterns this function is permitted to read.<br/>Each entry should be a full ARN or ARN pattern. This can be retrieved from platform.module.ssm.ssm\_root\_name.parameter\_name.arn.<br/>If empty (default), the function receives no SSM access.<br/>Do not use broad wildcards — scope each entry to the specific parameters this function requires. | `list(string)` | `[]` | no |
| <a name="input_timeout"></a> [timeout](#input\_timeout) | Lambda function timeout | `number` | `900` | no |

<!--WARNING: GENERATED CONTENT with terraform-docs, e.g.
     'terraform-docs --config "$(git rev-parse --show-toplevel)/.terraform-docs.yml" .'
     Manually updating sections between TF_DOCS tags may be overwritten.
     See https://terraform-docs.io/user-guide/configuration/ for more information.
-->
## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_subnets"></a> [subnets](#module\_subnets) | ../subnets | n/a |
| <a name="module_vpc"></a> [vpc](#module\_vpc) | ../vpc | n/a |
| <a name="module_zip_bucket"></a> [zip\_bucket](#module\_zip\_bucket) | ../bucket | n/a |

<!--WARNING: GENERATED CONTENT with terraform-docs, e.g.
     'terraform-docs --config "$(git rev-parse --show-toplevel)/.terraform-docs.yml" .'
     Manually updating sections between TF_DOCS tags may be overwritten.
     See https://terraform-docs.io/user-guide/configuration/ for more information.
-->
## Resources

| Name | Type |
|------|------|
| [aws_cloudwatch_event_rule.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_rule) | resource |
| [aws_cloudwatch_event_target.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_target) | resource |
| [aws_cloudwatch_log_group.function](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_iam_role.function](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.default_function](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.extra_policies](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_lambda_function.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_permission.cloudwatch_events](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_permission) | resource |
| [aws_s3_object.empty_function_zip](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_object) | resource |
| [aws_s3_object.function_zip](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_object) | resource |
| [aws_security_group.function](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [archive_file.function](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_openid_connect_provider.github](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_openid_connect_provider) | data source |
| [aws_iam_policy_document.cicd_manage_lambda_objects](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.default_function](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.function_assume_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_role.admin](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_role) | data source |
| [aws_iam_role.dasg_admin](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_role) | data source |
| [aws_kms_alias.kms_key](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/kms_alias) | data source |

<!--WARNING: GENERATED CONTENT with terraform-docs, e.g.
     'terraform-docs --config "$(git rev-parse --show-toplevel)/.terraform-docs.yml" .'
     Manually updating sections between TF_DOCS tags may be overwritten.
     See https://terraform-docs.io/user-guide/configuration/ for more information.
-->
## Outputs

| Name | Description |
|------|-------------|
| <a name="output_name"></a> [name](#output\_name) | Name for the lambda function |
| <a name="output_role_arn"></a> [role\_arn](#output\_role\_arn) | ARN of the IAM role for the function |
| <a name="output_security_group_id"></a> [security\_group\_id](#output\_security\_group\_id) | ID for the security group for the function |
| <a name="output_zip_bucket"></a> [zip\_bucket](#output\_zip\_bucket) | Bucket name for the function.zip file |
<!-- END_TF_DOCS -->