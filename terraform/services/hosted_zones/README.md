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
| <a name="input_app"></a> [app](#input\_app) | The application name (ab2d, bcda, dpc, cdap) | `string` | n/a | yes |
| <a name="input_env"></a> [env](#input\_env) | The application environment (dev, test, mgmt, sbx, sandbox, prod) | `string` | n/a | yes |

<!--WARNING: GENERATED CONTENT with terraform-docs, e.g.
     'terraform-docs --config "$(git rev-parse --show-toplevel)/.terraform-docs.yml" .'
     Manually updating sections between TF_DOCS tags may be overwritten.
     See https://terraform-docs.io/user-guide/configuration/ for more information.
-->
## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_platform"></a> [platform](#module\_platform) | ../../modules/platform | n/a |

<!--WARNING: GENERATED CONTENT with terraform-docs, e.g.
     'terraform-docs --config "$(git rev-parse --show-toplevel)/.terraform-docs.yml" .'
     Manually updating sections between TF_DOCS tags may be overwritten.
     See https://terraform-docs.io/user-guide/configuration/ for more information.
-->
## Resources

| Name | Type |
|------|------|
| [aws_route53_zone.internal](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_zone) | resource |
| [aws_route53_zone.zscaler](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_zone) | resource |

<!--WARNING: GENERATED CONTENT with terraform-docs, e.g.
     'terraform-docs --config "$(git rev-parse --show-toplevel)/.terraform-docs.yml" .'
     Manually updating sections between TF_DOCS tags may be overwritten.
     See https://terraform-docs.io/user-guide/configuration/ for more information.
-->
## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cms_dns_registration_instructions"></a> [cms\_dns\_registration\_instructions](#output\_cms\_dns\_registration\_instructions) | Rendered instructions for registering this hosted zone with CMS DNS/networking. |
| <a name="output_internal_hosted_zone_id"></a> [internal\_hosted\_zone\_id](#output\_internal\_hosted\_zone\_id) | The Route53 Hosted Zone ID that allows developer access. Provide this to CMS DNS/networking team for zone delegation or discovery registration. |
| <a name="output_internal_hosted_zone_name"></a> [internal\_hosted\_zone\_name](#output\_internal\_hosted\_zone\_name) | The fully qualified domain name of the hosted zone accessible by VPC only. |
| <a name="output_internal_hosted_zone_name_servers"></a> [internal\_hosted\_zone\_name\_servers](#output\_internal\_hosted\_zone\_name\_servers) | Name servers assigned to this hosted zone by Route53. |
| <a name="output_zscaler_hosted_zone_id"></a> [zscaler\_hosted\_zone\_id](#output\_zscaler\_hosted\_zone\_id) | The Route53 Hosted Zone ID that allows developer access. Provide this to CMS DNS/networking team for zone delegation or discovery registration. |
| <a name="output_zscaler_hosted_zone_name"></a> [zscaler\_hosted\_zone\_name](#output\_zscaler\_hosted\_zone\_name) | The fully qualified domain name of the zscaler-friendly hosted zone. |
| <a name="output_zscaler_hosted_zone_name_servers"></a> [zscaler\_hosted\_zone\_name\_servers](#output\_zscaler\_hosted\_zone\_name\_servers) | Name servers assigned to this hosted zone by Route53. Required for public zone NS delegation — provide these to the CMS DNS team. |
<!-- END_TF_DOCS -->