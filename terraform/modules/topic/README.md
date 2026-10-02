<!-- BEGIN_TF_DOCS -->
<!--WARNING: GENERATED CONTENT with terraform-docs, e.g.
     'terraform-docs --config "$(git rev-parse --show-toplevel)/.terraform-docs.yml" .'
     Manually updating sections between TF_DOCS tags may be overwritten.
     See https://terraform-docs.io/user-guide/configuration/ for more information.
-->
## Providers

| Name | Version |
|------|---------|
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
| <a name="input_name"></a> [name](#input\_name) | Short name for this topic's purpose, e.g. "alarms" or "alarm-to-slack".<br/>Used to construct the default topic name and, if enabled, the default<br/>SSM parameter path. | `string` | n/a | yes |
| <a name="input_platform"></a> [platform](#input\_platform) | Object that describes standardized platform values. Must expose app, env, service, and kms\_alias\_primary.target\_key\_arn. | `any` | n/a | yes |
| <a name="input_additional_publisher_iam_arns"></a> [additional\_publisher\_iam\_arns](#input\_additional\_publisher\_iam\_arns) | IAM role/user ARNs granted sns:Publish directly on this topic. This<br/>module does not create those IAM identities -- it only grants the<br/>topic-side resource policy statement; the consuming terraservice owns<br/>the role/user itself. | `list(string)` | `[]` | no |
| <a name="input_additional_publisher_service_principals"></a> [additional\_publisher\_service\_principals](#input\_additional\_publisher\_service\_principals) | Additional AWS service principals (e.g. "ec2.amazonaws.com") granted sns:Publish on this topic. | `list(string)` | `[]` | no |
| <a name="input_additional_subscriptions"></a> [additional\_subscriptions](#input\_additional\_subscriptions) | Non-SQS subscriptions, e.g. VictorOps via https, or email. | <pre>list(object({<br/>    protocol = string<br/>    endpoint = string<br/>  }))</pre> | `[]` | no |
| <a name="input_allow_cloudwatch_publish"></a> [allow\_cloudwatch\_publish](#input\_allow\_cloudwatch\_publish) | If true, grants cloudwatch.amazonaws.com sns:Publish on this topic. Needed when a CloudWatch alarm targets this topic as an alarm action. | `bool` | `false` | no |
| <a name="input_allow_eventbridge_publish"></a> [allow\_eventbridge\_publish](#input\_allow\_eventbridge\_publish) | If true, grants events.amazonaws.com sns:Publish on this topic. Needed when an EventBridge rule targets this topic. | `bool` | `false` | no |
| <a name="input_buckets"></a> [buckets](#input\_buckets) | ARNs of S3 buckets that need to publish event notifications to this<br/>topic. When non-empty, adds a topic policy statement allowing<br/>s3.amazonaws.com to publish. | `list(string)` | `[]` | no |
| <a name="input_create_ssm_parameter"></a> [create\_ssm\_parameter](#input\_create\_ssm\_parameter) | Publishes this topic's ARN to SSM Parameter Store, at<br/>ssm\_parameter\_name\_override if set, otherwise at the default path<br/>constructed from platform.app, platform.env, platform.service, and<br/>var.name. Off by default -- not every topic needs to be discoverable<br/>by other terraservices. | `bool` | `false` | no |
| <a name="input_kms_key_override"></a> [kms\_key\_override](#input\_kms\_key\_override) | Do not favor. Override to the platform-managed KMS key. Defaults to var.platform.kms\_alias\_primary.target\_key\_arn. | `string` | `null` | no |
| <a name="input_sqs_subscriptions"></a> [sqs\_subscriptions](#input\_sqs\_subscriptions) | Names of existing SQS queues (looked up by name, not created by this module) to subscribe to this topic. | `list(string)` | `[]` | no |
| <a name="input_ssm_parameter_name_override"></a> [ssm\_parameter\_name\_override](#input\_ssm\_parameter\_name\_override) | Overrides the constructed SSM parameter path entirely. Only used when create\_ssm\_parameter = true. | `string` | `null` | no |
| <a name="input_topic_name_override"></a> [topic\_name\_override](#input\_topic\_name\_override) | Overrides the constructed topic name ({platform.app}-{platform.env}-<br/>{name}) entirely. SNS topic names are immutable in AWS -- changing<br/>this later forces the topic to be destroyed and recreated. Required<br/>when adopting this module for an existing topic whose name predates<br/>this convention. | `string` | `null` | no |

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
| [aws_sns_topic.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic) | resource |
| [aws_sns_topic_policy.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic_policy) | resource |
| [aws_sns_topic_subscription.additional](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic_subscription) | resource |
| [aws_sns_topic_subscription.sqs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic_subscription) | resource |
| [aws_ssm_parameter.topic_arn](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_sqs_queue.subscriptions](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/sqs_queue) | data source |

<!--WARNING: GENERATED CONTENT with terraform-docs, e.g.
     'terraform-docs --config "$(git rev-parse --show-toplevel)/.terraform-docs.yml" .'
     Manually updating sections between TF_DOCS tags may be overwritten.
     See https://terraform-docs.io/user-guide/configuration/ for more information.
-->
## Outputs

| Name | Description |
|------|-------------|
| <a name="output_arn"></a> [arn](#output\_arn) | ARN for the SNS topic |
<!-- END_TF_DOCS -->