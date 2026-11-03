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
| <a name="input_platform"></a> [platform](#input\_platform) | Object representing the CDAP platform module. | <pre>object({<br/>    app             = string<br/>    env             = string<br/>    service         = string<br/>    vpc_id          = string<br/>    private_subnets = map(object({ id = string }))<br/>  })</pre> | n/a | yes |
| <a name="input_target_domain_name"></a> [target\_domain\_name](#input\_target\_domain\_name) | The target's acm\_certificate\_private "internal\_domain" output, e.g.<br/>"myservice.dev.bcda.internal.cms.gov" — the primary domain the<br/>target's cert was issued for.<br/><br/>This module creates a new private hosted zone with this name,<br/>associated only to this VPC, and one CNAME<br/>inside it: "<this app>.<target\_domain\_name>", pointing at this VPC's<br/>endpoint ENIs.<br/><br/>That record name must also appear as an entry in the target's<br/>enrolled\_upstream\_apps list (keyed on var.platform.app). If it<br/>doesn't, DNS still resolves, but TLS will fail, since the <br/>target's cert has no SAN for a name that was never enrolled. | `string` | n/a | yes |
| <a name="input_dns_record_name"></a> [dns\_record\_name](#input\_dns\_record\_name) | Subdomain label for the friendly CNAME, e.g. 'bcda-target'. Required if create\_friendly\_dns\_record is true. | `string` | `null` | no |
| <a name="input_service_name"></a> [service\_name](#input\_service\_name) | VPC endpoint service\_name (vpce-svc-...) to connect to. Provide this or ssm\_parameter\_name, not both. | `string` | `null` | no |
| <a name="input_ssm_parameter_name"></a> [ssm\_parameter\_name](#input\_ssm\_parameter\_name) | SSM parameter path to read the endpoint service\_name from, published by<br/>the producer's lb module (privatelink\_ssm\_parameter\_name output).<br/>Provide this or service\_name, not both. | `string` | `null` | no |

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
| [aws_route53_record.friendly_name](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_zone.target_shadow](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_zone) | resource |
| [aws_security_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_vpc_endpoint.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint) | resource |
| [aws_ssm_parameter.service_name](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |

<!--WARNING: GENERATED CONTENT with terraform-docs, e.g.
     'terraform-docs --config "$(git rev-parse --show-toplevel)/.terraform-docs.yml" .'
     Manually updating sections between TF_DOCS tags may be overwritten.
     See https://terraform-docs.io/user-guide/configuration/ for more information.
-->
## Outputs

| Name | Description |
|------|-------------|
| <a name="output_friendly_dns_name"></a> [friendly\_dns\_name](#output\_friendly\_dns\_name) | "<this app>.<target\_domain\_name>" that resolves only within this VPC,<br/>via the shadow zone this module creates. Matches a SAN on the<br/>target's cert if this app is enrolled there. Use this to build<br/>DOWNSTREAM\_URL. |
| <a name="output_security_group_id"></a> [security\_group\_id](#output\_security\_group\_id) | The endpoint's security group — managed or passed-in. Use this to add ingress rules for calling services. |
| <a name="output_vpc_endpoint_dns_name"></a> [vpc\_endpoint\_dns\_name](#output\_vpc\_endpoint\_dns\_name) | AWS-generated regional DNS name for the endpoint. |
| <a name="output_vpc_endpoint_id"></a> [vpc\_endpoint\_id](#output\_vpc\_endpoint\_id) | n/a |
<!-- END_TF_DOCS -->