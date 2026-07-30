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
| <a name="input_acm_certificate_arn"></a> [acm\_certificate\_arn](#input\_acm\_certificate\_arn) | ARN of the ACM certificate (public or private CA) for the HTTPS listener.<br/>   Pass either:<br/>     - module.acm.private\_cert\_arn  for internal/Zscaler endpoints<br/>     - module.acm.public\_cert\_arn   for public *.<app>.cms.gov endpoints<br/>   Required — this module enforces TLS on all listeners. | `string` | n/a | yes |
| <a name="input_platform"></a> [platform](#input\_platform) | Object representing the CDAP platform module. | <pre>object({<br/>    app             = string<br/>    env             = string<br/>    primary_region  = object({ name = string })<br/>    private_subnets = map(object({ id = string }))<br/>    service         = string<br/>    vpc_id          = string<br/>    security_groups = map(object({<br/>      id   = string<br/>      arn  = string<br/>      name = string<br/>    }))<br/>  })</pre> | n/a | yes |
| <a name="input_enable_datadog_synthetics_ingress"></a> [enable\_datadog\_synthetics\_ingress](#input\_enable\_datadog\_synthetics\_ingress) | When true, adds an ingress rule allowing the Datadog synthetics<br/>private location runner to reach the ALB on HTTPS:443.<br/>Use in dev/test environments where Datadog private location<br/>synthetic tests are configured against this ALB. | `bool` | `false` | no |
| <a name="input_enable_http_redirect"></a> [enable\_http\_redirect](#input\_enable\_http\_redirect) | When true, adds an HTTP:80 listener that redirects all traffic to HTTPS:443. | `bool` | `true` | no |
| <a name="input_enable_zscaler_ingress"></a> [enable\_zscaler\_ingress](#input\_enable\_zscaler\_ingress) | When true, adds an ingress rule allowing the Zscaler private App<br/>Connector to reach the ALB on HTTPS:443.<br/>Enable this when the ALB is registered in cmscloud.local DNS and<br/>accessed by developers via Zscaler.<br/>Should be set alongside enable\_zscaler\_endpoint = true on the<br/>acm\_certificate module. | `bool` | `false` | no |
| <a name="input_extra_listeners"></a> [extra\_listeners](#input\_extra\_listeners) | Additional HTTPS listeners beyond the default 443 | <pre>map(object({<br/>    port                = number<br/>    acm_certificate_arn = optional(string)<br/>    ssl_policy          = optional(string)<br/>  }))</pre> | `{}` | no |
| <a name="input_internal"></a> [internal](#input\_internal) | true = private (internal) ALB; false = public (internet-facing) ALB. | `bool` | `true` | no |
| <a name="input_name_override"></a> [name\_override](#input\_name\_override) | Override for the ALB name. Defaults to '<var.platform.app>-<var.platform.env>-<var.platform.service>-alb'. | `string` | `null` | no |
| <a name="input_security_group_ids"></a> [security\_group\_ids](#input\_security\_group\_ids) | Security group IDs to attach to the ALB. | `list(string)` | `[]` | no |
| <a name="input_ssl_policy"></a> [ssl\_policy](#input\_ssl\_policy) | TLS security policy. Default enforces TLS 1.2+ per CMS/FISMA requirements. | `string` | `"ELBSecurityPolicy-TLS13-1-2-2021-06"` | no |
| <a name="input_subnet_ids"></a> [subnet\_ids](#input\_subnet\_ids) | Override subnet placement. Defaults to platform private subnets for internal ALBs<br/>and platform public subnets for internet-facing ALBs.<br/>Only set this if you need non-standard subnet placement. | `list(string)` | `null` | no |

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
| [aws_lb.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb) | resource |
| [aws_lb_listener.http_redirect](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener) | resource |
| [aws_lb_listener.https](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener) | resource |
| [aws_security_group.alb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_vpc_security_group_ingress_rule.http](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.https_datadog](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.https_public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.https_security_tools](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.https_zscaler](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |

<!--WARNING: GENERATED CONTENT with terraform-docs, e.g.
     'terraform-docs --config "$(git rev-parse --show-toplevel)/.terraform-docs.yml" .'
     Manually updating sections between TF_DOCS tags may be overwritten.
     See https://terraform-docs.io/user-guide/configuration/ for more information.
-->
## Outputs

| Name | Description |
|------|-------------|
| <a name="output_alb_arn"></a> [alb\_arn](#output\_alb\_arn) | ARN of the ALB. |
| <a name="output_alb_dns_name"></a> [alb\_dns\_name](#output\_alb\_dns\_name) | DNS name of the ALB — use this for Route 53 alias records. |
| <a name="output_alb_zone_id"></a> [alb\_zone\_id](#output\_alb\_zone\_id) | Hosted zone ID of the ALB — required for Route 53 alias records. |
| <a name="output_https_listener_arn"></a> [https\_listener\_arn](#output\_https\_listener\_arn) | ARN of the HTTPS:443 listener. Listener can be used in downstream modules. |
| <a name="output_internal"></a> [internal](#output\_internal) | Whether the ALB is internal (private) or internet-facing. |
| <a name="output_security_group_id"></a> [security\_group\_id](#output\_security\_group\_id) | ID of the module-managed ALB security group.<br/>Null when security\_group\_ids are provided externally.<br/>Use this in the caller terraservice to wire egress rules from the ALB<br/>to ECS task security groups:<br/><br/>resource "aws\_vpc\_security\_group\_egress\_rule" "alb\_to\_service" {<br/>  security\_group\_id            = module.alb.security\_group\_id<br/>  referenced\_security\_group\_id = module.ecs\_service.task\_security\_group\_id<br/>  from\_port                    = 8443<br/>  to\_port                      = 8443<br/>  ip\_protocol                  = "tcp"<br/>} |
<!-- END_TF_DOCS -->