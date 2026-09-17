# 701-log-retention

Provisions the per-AWS-account long-term log storage bucket (one per CDAP
account: test and prod) that retains logs in accordance with HIPAA requirements.

## What this creates

- An S3 bucket (via the [bucket module](../../modules/bucket)) with:
  - **S3 Object Lock (WORM)** in **Compliance** mode with a 6-year default
    retention in prod — objects cannot be overwritten or deleted by anyone,
    including the root account, until retention expires. Test buckets have no
    Object Lock so misdelivered data is recoverable while iterating
  - A bucket policy denying `s3:PutObject` to every principal except the
    Firehose delivery role and vended log delivery (VPC Flow Logs and
    CloudFront v2 under `vpc-flow-logs/` and `cloudfront/`), each scoped to
    its prefix and this account
  - Versioning (required by Object Lock)
  - Server access logging to the account's `bucket-access-logs` bucket
  - TLS-only bucket policy; read access is deny-by-default via IAM least
    privilege
  - Storage class transitions: `STANDARD_IA` at 30 days, `GLACIER_IR` at 365
    days (Glacier Instant Retrieval keeps objects directly queryable via
    Athena without a restore step)
  - A lifecycle rule that securely deletes current and noncurrent versions at
    2200 days, after the 6-year Object Lock retention has elapsed
- A dedicated KMS CMK (with automatic annual rotation) used only by this
  service's pipeline (bucket, Firehose stream, diagnostics log group), so log
  encryption is managed independently of the account default
  key
- A Kinesis Firehose delivery stream that receives CloudWatch Logs
  subscription filter data, decompresses the CloudWatch envelope in-stream
  (so objects land as single-GZIP JSON queryable by Athena), and dynamically
  partitions S3 keys by source log group:
  `cloudwatch/<log-group>/yyyy/MM/dd/`. Failed records land under
  `firehose-errors/` — note these are also subject to Object Lock retention
- IAM roles for Firehose -> S3 (writes limited to the `cloudwatch/` and
  `firehose-errors/` prefixes) and CloudWatch Logs -> Firehose (assumed by
  subscription filters via `logs.amazonaws.com`)
- CloudWatch alarms routed to the CDAP alarm topic for delivery failures,
  data freshness, and throttling
- SSM parameters exposing the bucket name, Firehose ARN, and subscription
  role ARN to log producers, under
  `/cdap/<env>/common/nonsensitive/log-retention/`:
  - `.../bucket`
  - `.../firehose-arn`
  - `.../subscription-role-arn`

<!-- BEGIN_TF_DOCS -->
<!--WARNING: GENERATED CONTENT with terraform-docs, e.g.
     'terraform-docs --config "$(git rev-parse --show-toplevel)/.terraform-docs.yml" .'
     Manually updating sections between TF_DOCS tags may be overwritten.
     See https://terraform-docs.io/user-guide/configuration/ for more information.
-->
## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.64.0 |

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
| <a name="input_env"></a> [env](#input\_env) | The application environment (test) | `string` | n/a | yes |

<!--WARNING: GENERATED CONTENT with terraform-docs, e.g.
     'terraform-docs --config "$(git rev-parse --show-toplevel)/.terraform-docs.yml" .'
     Manually updating sections between TF_DOCS tags may be overwritten.
     See https://terraform-docs.io/user-guide/configuration/ for more information.
-->
## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_firehose_log_group"></a> [firehose\_log\_group](#module\_firehose\_log\_group) | ../../modules/cloudwatch_log_group | n/a |
| <a name="module_log_bucket"></a> [log\_bucket](#module\_log\_bucket) | ../../modules/bucket | n/a |
| <a name="module_platform"></a> [platform](#module\_platform) | ../../modules/platform | n/a |

<!--WARNING: GENERATED CONTENT with terraform-docs, e.g.
     'terraform-docs --config "$(git rev-parse --show-toplevel)/.terraform-docs.yml" .'
     Manually updating sections between TF_DOCS tags may be overwritten.
     See https://terraform-docs.io/user-guide/configuration/ for more information.
-->
## Resources

| Name | Type |
| ---- | ---- |
| [aws_cloudwatch_log_stream.firehose_s3_delivery](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_stream) | resource |
| [aws_cloudwatch_metric_alarm.firehose_data_freshness](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_cloudwatch_metric_alarm.firehose_delivery_failure](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_cloudwatch_metric_alarm.firehose_throttled_records](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_iam_role.cloudwatch_to_firehose](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.firehose](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.cloudwatch_to_firehose](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.firehose](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_kinesis_firehose_delivery_stream.log_retention](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kinesis_firehose_delivery_stream) | resource |
| [aws_kms_alias.log_retention](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_alias) | resource |
| [aws_kms_key.log_retention](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |
| [aws_ssm_parameter.cloudwatch_to_firehose_role_arn](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_ssm_parameter.firehose_arn](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_iam_policy_document.cloudwatch_to_firehose](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.cloudwatch_to_firehose_assume](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.firehose_assume](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.firehose_delivery](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.log_bucket_writes](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.log_retention_kms](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_ssm_parameter.cloudwatch_alarms_topic_arn](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |

<!--WARNING: GENERATED CONTENT with terraform-docs, e.g.
     'terraform-docs --config "$(git rev-parse --show-toplevel)/.terraform-docs.yml" .'
     Manually updating sections between TF_DOCS tags may be overwritten.
     See https://terraform-docs.io/user-guide/configuration/ for more information.
-->
## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_bucket_arn"></a> [bucket\_arn](#output\_bucket\_arn) | ARN of the long-term log retention bucket |
| <a name="output_bucket_id"></a> [bucket\_id](#output\_bucket\_id) | ID of the long-term log retention bucket |
| <a name="output_cloudwatch_to_firehose_role_arn"></a> [cloudwatch\_to\_firehose\_role\_arn](#output\_cloudwatch\_to\_firehose\_role\_arn) | ARN of the role CloudWatch Logs subscription filters assume to write to the Firehose |
| <a name="output_firehose_arn"></a> [firehose\_arn](#output\_firehose\_arn) | ARN of the log delivery Firehose stream |
| <a name="output_kms_key_arn"></a> [kms\_key\_arn](#output\_kms\_key\_arn) | ARN of the dedicated log encryption key |
<!-- END_TF_DOCS -->
