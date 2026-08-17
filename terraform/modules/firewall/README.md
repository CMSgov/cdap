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
| <a name="input_app"></a> [app](#input\_app) | The application name (ab2d, bcda, dpc) | `string` | n/a | yes |
| <a name="input_content_type"></a> [content\_type](#input\_content\_type) | Content type for firewall responses | `string` | n/a | yes |
| <a name="input_env"></a> [env](#input\_env) | The application environment (dev, test, sbx, sandbox, prod) | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Web ACL name | `string` | n/a | yes |
| <a name="input_platform"></a> [platform](#input\_platform) | Object representing the CDAP plaform module. | <pre>object({<br/>    kms_alias_primary = object({ target_key_arn = string })<br/>    account_id        = string<br/>  })</pre> | n/a | yes |
| <a name="input_scope"></a> [scope](#input\_scope) | Firewall scope | `string` | n/a | yes |
| <a name="input_associated_resource_arn"></a> [associated\_resource\_arn](#input\_associated\_resource\_arn) | ARN of the resource to associate the WAF with. | `string` | `""` | no |
| <a name="input_ip_sets"></a> [ip\_sets](#input\_ip\_sets) | IP sets to allow | `list(string)` | `[]` | no |
| <a name="input_logging_filter"></a> [logging\_filter](#input\_logging\_filter) | Filter to control which requests get logged. Defaults to BLOCK and COUNT only. Override during initial rollout to KEEP all traffic. | <pre>object({<br/>    default_behavior = string<br/>    filters = list(object({<br/>      behavior    = string<br/>      requirement = string<br/>      conditions = list(object({<br/>        action_condition     = optional(string, "")<br/>        label_name_condition = optional(string, "")<br/>      }))<br/>    }))<br/>  })</pre> | <pre>{<br/>  "default_behavior": "DROP",<br/>  "filters": [<br/>    {<br/>      "behavior": "KEEP",<br/>      "conditions": [<br/>        {<br/>          "action_condition": "BLOCK"<br/>        },<br/>        {<br/>          "action_condition": "COUNT"<br/>        }<br/>      ],<br/>      "requirement": "MEETS_ANY"<br/>    }<br/>  ]<br/>}</pre> | no |
| <a name="input_rate_limit"></a> [rate\_limit](#input\_rate\_limit) | IP rate limit for every 5 minutes | `number` | `3000` | no |

<!--WARNING: GENERATED CONTENT with terraform-docs, e.g.
     'terraform-docs --config "$(git rev-parse --show-toplevel)/.terraform-docs.yml" .'
     Manually updating sections between TF_DOCS tags may be overwritten.
     See https://terraform-docs.io/user-guide/configuration/ for more information.
-->
## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_waf_log_group"></a> [waf\_log\_group](#module\_waf\_log\_group) | ../cloudwatch_log_group | n/a |

<!--WARNING: GENERATED CONTENT with terraform-docs, e.g.
     'terraform-docs --config "$(git rev-parse --show-toplevel)/.terraform-docs.yml" .'
     Manually updating sections between TF_DOCS tags may be overwritten.
     See https://terraform-docs.io/user-guide/configuration/ for more information.
-->
## Resources

| Name | Type |
|------|------|
| [aws_cloudwatch_log_resource_policy.waf](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_resource_policy) | resource |
| [aws_wafv2_web_acl.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/wafv2_web_acl) | resource |
| [aws_wafv2_web_acl_association.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/wafv2_web_acl_association) | resource |
| [aws_wafv2_web_acl_logging_configuration.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/wafv2_web_acl_logging_configuration) | resource |

<!--WARNING: GENERATED CONTENT with terraform-docs, e.g.
     'terraform-docs --config "$(git rev-parse --show-toplevel)/.terraform-docs.yml" .'
     Manually updating sections between TF_DOCS tags may be overwritten.
     See https://terraform-docs.io/user-guide/configuration/ for more information.
-->
## Outputs

| Name | Description |
|------|-------------|
| <a name="output_arn"></a> [arn](#output\_arn) | The ARN of the WAF WebACL. |
<!-- END_TF_DOCS -->