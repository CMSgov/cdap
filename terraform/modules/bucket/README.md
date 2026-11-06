<!-- BEGIN_TF_DOCS -->
<!--WARNING: GENERATED CONTENT with terraform-docs, e.g.
     'terraform-docs --config "$(git rev-parse --show-toplevel)/.terraform-docs.yml" .'
     Manually updating sections between TF_DOCS tags may be overwritten.
     See https://terraform-docs.io/user-guide/configuration/ for more information.
-->
## Providers

| Name | Version |
| ---- | ------- |
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
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_app"></a> [app](#input\_app) | The application name (ab2d, bcda, dpc, cdap) | `string` | n/a | yes |
| <a name="input_env"></a> [env](#input\_env) | The application environment (dev, test, sandbox, prod, mgmt) | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Name for the S3 bucket | `string` | n/a | yes |
| <a name="input_platform"></a> [platform](#input\_platform) | Object representing the CDAP platform module. Used to encrypt the access-logging log group with the account's primary KMS key. | <pre>object({<br/>    kms_alias_primary = object({ target_key_arn = string })<br/>  })</pre> | n/a | yes |
| <a name="input_access_logging"></a> [access\_logging](#input\_access\_logging) | Server access log delivery route. cloudwatch (the default) delivers through a per-bucket CloudWatch log group and the shared log-retention Firehose into the log-retention bucket. External means the caller configures access logging itself, outside this module. Used by the log-retention bucket, which logs directly to the CMS bucket to avoid looping its own access logs back into itself. | `string` | `"cloudwatch"` | no |
| <a name="input_additional_bucket_policies"></a> [additional\_bucket\_policies](#input\_additional\_bucket\_policies) | A list of additional bucket policies to be merged with the default. | `list(string)` | `[]` | no |
| <a name="input_additional_bucket_statements"></a> [additional\_bucket\_statements](#input\_additional\_bucket\_statements) | Structured statements that will reference the bucket's ARN. Useful for iterative calls of the module. | <pre>list(object({<br/>    sid        = string<br/>    principals = list(string)<br/>    actions    = list(string)<br/>  }))</pre> | `[]` | no |
| <a name="input_expiration_days"></a> [expiration\_days](#input\_expiration\_days) | Days after object creation when current versions expire and noncurrent versions are permanently deleted. Must exceed any Object Lock retention period. | `number` | `null` | no |
| <a name="input_force_destroy"></a> [force\_destroy](#input\_force\_destroy) | Whether to allow Terraform to destroy this bucket even if it contains objects. Defaults to true to match existing behavior; set to false for buckets holding data you don't want accidentally wiped (e.g. cross-account export buckets). | `bool` | `true` | no |
| <a name="input_kms_key_arn"></a> [kms\_key\_arn](#input\_kms\_key\_arn) | Use sparingly. The ARN of a custom S3 bucket encryption key used for this bucket. | `string` | `null` | no |
| <a name="input_object_lock"></a> [object\_lock](#input\_object\_lock) | S3 Object Lock (WORM) default retention. Object Lock can only be enabled at bucket creation. Mode is GOVERNANCE or COMPLIANCE. | <pre>object({<br/>    mode  = string<br/>    years = number<br/>  })</pre> | `null` | no |
| <a name="input_ssm_parameter"></a> [ssm\_parameter](#input\_ssm\_parameter) | SSM Parameter path for bucket output | `string` | `null` | no |
| <a name="input_transitions"></a> [transitions](#input\_transitions) | Storage class transitions for current object versions. This is used currently in the long-term-log-retention bucket for cost savings on long-lived log objects for HIPAA compliance. | <pre>list(object({<br/>    days          = number<br/>    storage_class = string<br/>  }))</pre> | `[]` | no |
| <a name="input_use_custom_kms_key"></a> [use\_custom\_kms\_key](#input\_use\_custom\_kms\_key) | Set true when kms\_key\_arn is provided, even if its value isn't known until apply. | `bool` | `false` | no |

<!--WARNING: GENERATED CONTENT with terraform-docs, e.g.
     'terraform-docs --config "$(git rev-parse --show-toplevel)/.terraform-docs.yml" .'
     Manually updating sections between TF_DOCS tags may be overwritten.
     See https://terraform-docs.io/user-guide/configuration/ for more information.
-->
## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_access_logs_group"></a> [access\_logs\_group](#module\_access\_logs\_group) | ../cloudwatch_log_group | n/a |

<!--WARNING: GENERATED CONTENT with terraform-docs, e.g.
     'terraform-docs --config "$(git rev-parse --show-toplevel)/.terraform-docs.yml" .'
     Manually updating sections between TF_DOCS tags may be overwritten.
     See https://terraform-docs.io/user-guide/configuration/ for more information.
-->
## Resources

| Name | Type |
| ---- | ---- |
| [aws_cloudwatch_log_delivery.access_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_delivery) | resource |
| [aws_cloudwatch_log_delivery_destination.access_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_delivery_destination) | resource |
| [aws_cloudwatch_log_delivery_source.access_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_delivery_source) | resource |
| [aws_s3_bucket.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_lifecycle_configuration.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_lifecycle_configuration) | resource |
| [aws_s3_bucket_object_lock_configuration.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_object_lock_configuration) | resource |
| [aws_s3_bucket_policy.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy) | resource |
| [aws_s3_bucket_server_side_encryption_configuration.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |
| [aws_s3_bucket_versioning.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning) | resource |
| [aws_ssm_parameter.bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_iam_policy_document.ssl_only](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_kms_alias.default_encryption_key](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/kms_alias) | data source |

<!--WARNING: GENERATED CONTENT with terraform-docs, e.g.
     'terraform-docs --config "$(git rev-parse --show-toplevel)/.terraform-docs.yml" .'
     Manually updating sections between TF_DOCS tags may be overwritten.
     See https://terraform-docs.io/user-guide/configuration/ for more information.
-->
## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_arn"></a> [arn](#output\_arn) | ARN for the S3 bucket |
| <a name="output_bucket_regional_domain_name"></a> [bucket\_regional\_domain\_name](#output\_bucket\_regional\_domain\_name) | Bucket domain name. Will be of format 'bucketname.s3.amazonaws.com'. |
| <a name="output_id"></a> [id](#output\_id) | ID for the S3 bucket |
<!-- END_TF_DOCS -->