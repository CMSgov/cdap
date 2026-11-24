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
| <a name="input_acm_certificate_arn"></a> [acm\_certificate\_arn](#input\_acm\_certificate\_arn) | ARN of the ACM certificate (private CA) for the HTTPS listener.<br/>   Pass either:<br/>     - module.acm.private\_cert\_arn  for internal/Zscaler endpoints<br/>   Required — this module enforces TLS on all listeners. | `string` | n/a | yes |
| <a name="input_platform"></a> [platform](#input\_platform) | Object representing the CDAP platform module. | <pre>object({<br/>    account_env_suffix = string<br/>    account_id         = string<br/>    app                = string<br/>    cdap_env           = string<br/>    cdap_vpc_name      = string<br/>    env                = string<br/>    primary_region     = object({ name = string })<br/>    private_subnets    = map(object({ id = string }))<br/>    public_subnets     = map(object({ id = string }))<br/>    service            = string<br/>    vpc_cidr           = string<br/>    vpc_id             = string<br/>    security_groups = map(object({<br/>      id   = string<br/>      arn  = string<br/>      name = string<br/>    }))<br/>  })</pre> | n/a | yes |
| <a name="input_create_alb"></a> [create\_alb](#input\_create\_alb) | Create the Application Load Balancer. | `bool` | `true` | no |
| <a name="input_create_internal_dns_record"></a> [create\_internal\_dns\_record](#input\_create\_internal\_dns\_record) | Create a record reachable by other services in the AWS account.<br/>Creates `$private_record_name.$env.$app.internal.cms.gov` | `bool` | `false` | no |
| <a name="input_create_nlb"></a> [create\_nlb](#input\_create\_nlb) | Create the Network Load Balancer. | `bool` | `false` | no |
| <a name="input_create_zscaler_dns_record"></a> [create\_zscaler\_dns\_record](#input\_create\_zscaler\_dns\_record) | Create a record reachable by users in ZScaler network,<br/>if the hosted zone is registered with Zscaler team.<br/>Creates `$private_record_name.$env.$app.cmscloud.local` | `bool` | `false` | no |
| <a name="input_enable_datadog_synthetics_ingress"></a> [enable\_datadog\_synthetics\_ingress](#input\_enable\_datadog\_synthetics\_ingress) | When true, adds an ingress rule allowing the Datadog synthetics<br/>private location runner to reach the ALB on HTTPS:443.<br/>Use in dev/test environments where Datadog private location<br/>synthetic tests are configured against this ALB. | `bool` | `false` | no |
| <a name="input_enable_deletion_protection"></a> [enable\_deletion\_protection](#input\_enable\_deletion\_protection) | Override deletion protection on the ALB. Leave null to default to true for external (!internal) ALBs and false for internal ones. | `bool` | `null` | no |
| <a name="input_enable_ingress_from_codebuild_repo"></a> [enable\_ingress\_from\_codebuild\_repo](#input\_enable\_ingress\_from\_codebuild\_repo) | When set, adds an ingress rule allowing that repo's CodeBuild security group access through 443. Null disables this rule entirely. | `string` | `null` | no |
| <a name="input_enable_privatelink"></a> [enable\_privatelink](#input\_enable\_privatelink) | Create an internal NLB + VPC Endpoint Service for cross-VPC PrivateLink access. Requires create\_nlb = true. | `bool` | `false` | no |
| <a name="input_http_redirect_target_port"></a> [http\_redirect\_target\_port](#input\_http\_redirect\_target\_port) | Port the plain-HTTP listener redirects to. Must match a key's port in https\_listeners. | `number` | `443` | no |
| <a name="input_https_listeners"></a> [https\_listeners](#input\_https\_listeners) | HTTPS listeners for this ALB. Every entry enforces TLS 1.3 — there is no plain-HTTP option. | <pre>map(object({<br/>    port                               = optional(number, 443)<br/>    certificate_arn                    = string<br/>    default_action_type                = optional(string, "fixed-response")<br/>    default_target_group_arn           = optional(string)<br/>    default_fixed_response_status_code = optional(number, 404)<br/>  }))</pre> | `{}` | no |
| <a name="input_internal"></a> [internal](#input\_internal) | true = private (internal) ALB; false = public (internet-facing) ALB. | `bool` | `true` | no |
| <a name="input_name_override"></a> [name\_override](#input\_name\_override) | Override for the ALB name. Defaults to '<var.platform.app>-<var.platform.env>-<var.platform.service>-alb'. | `string` | `null` | no |
| <a name="input_nlb_mode"></a> [nlb\_mode](#input\_nlb\_mode) | What the NLB forwards to, when create\_nlb is true:<br/>  "front\_alb" - used for PrivateLink in front of an<br/>                existing ALB.<br/>  "direct"    - module creates only the bare NLB and its security group.<br/>                Can be used for direct to Fargate / mTLS-passthrough traffic. | `string` | `"front_alb"` | no |
| <a name="input_private_record_name"></a> [private\_record\_name](#input\_private\_record\_name) | Subdomain label for this ALB's record, e.g. 'api-admin' | `string` | `null` | no |
| <a name="input_privatelink_health_check_path"></a> [privatelink\_health\_check\_path](#input\_privatelink\_health\_check\_path) | Path the NLB target group health-checks on the ALB. Must return 2xx/3xx — not the default 404 fixed-response. | `string` | `"/healthz"` | no |
| <a name="input_privatelink_private_dns_name"></a> [privatelink\_private\_dns\_name](#input\_privatelink\_private\_dns\_name) | Verified domain name for this PrivateLink service. Leave null unless public-DNS verification is confirmed possible for this domain. | `string` | `null` | no |
| <a name="input_privatelink_target_port"></a> [privatelink\_target\_port](#input\_privatelink\_target\_port) | Port the PrivateLink NLB listens on. Only used when nlb\_mode = "front\_alb"; must match a port in var.https\_listeners. Ignored in "direct" mode. | `number` | `443` | no |
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
| [aws_lb.network](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb) | resource |
| [aws_lb.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb) | resource |
| [aws_lb_listener.http](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener) | resource |
| [aws_lb_listener.https](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener) | resource |
| [aws_lb_listener.network](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener) | resource |
| [aws_lb_target_group.network_to_alb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group) | resource |
| [aws_lb_target_group_attachment.network_to_alb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group_attachment) | resource |
| [aws_route53_record.internal_alb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_record.zscaler_alb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_security_group.alb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.nlb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_ssm_parameter.privatelink_service_name](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_vpc_endpoint_service.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint_service) | resource |
| [aws_vpc_endpoint_service_private_dns_verification.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint_service_private_dns_verification) | resource |
| [aws_vpc_security_group_ingress_rule.codebuild](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.http](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.https_datadog](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.https_from_nlb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.https_public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.https_security_tools](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.https_zscaler](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.nlb_from_vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_route53_zone.internal](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/route53_zone) | data source |
| [aws_route53_zone.zscaler](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/route53_zone) | data source |
| [aws_security_group.codebuild_repo](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/security_group) | data source |
| [aws_ssm_parameter.datadog_private_location_sg](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |

<!--WARNING: GENERATED CONTENT with terraform-docs, e.g.
     'terraform-docs --config "$(git rev-parse --show-toplevel)/.terraform-docs.yml" .'
     Manually updating sections between TF_DOCS tags may be overwritten.
     See https://terraform-docs.io/user-guide/configuration/ for more information.
-->
## Outputs

| Name | Description |
|------|-------------|
| <a name="output_alb_arn"></a> [alb\_arn](#output\_alb\_arn) | ------------------------------------------------------- ALB ------------------------------------------------------- |
| <a name="output_alb_arn_suffix"></a> [alb\_arn\_suffix](#output\_alb\_arn\_suffix) | Used for CloudWatch metric dimensions / WAF association. |
| <a name="output_alb_dns_name"></a> [alb\_dns\_name](#output\_alb\_dns\_name) | n/a |
| <a name="output_alb_security_group_id"></a> [alb\_security\_group\_id](#output\_alb\_security\_group\_id) | n/a |
| <a name="output_alb_zone_id"></a> [alb\_zone\_id](#output\_alb\_zone\_id) | n/a |
| <a name="output_http_listener_arn"></a> [http\_listener\_arn](#output\_http\_listener\_arn) | n/a |
| <a name="output_https_listener_arns"></a> [https\_listener\_arns](#output\_https\_listener\_arns) | Map of listener port => ARN, for ecs-service's var.alb\_listener\_arn. |
| <a name="output_internal_dns_record_fqdn"></a> [internal\_dns\_record\_fqdn](#output\_internal\_dns\_record\_fqdn) | FQDN of the internal.cms.gov alias record, if created. |
| <a name="output_nlb_arn"></a> [nlb\_arn](#output\_nlb\_arn) | Pass to ecs-service's future enable\_nlb\_integration when nlb\_mode = "direct". |
| <a name="output_nlb_dns_name"></a> [nlb\_dns\_name](#output\_nlb\_dns\_name) | n/a |
| <a name="output_nlb_security_group_id"></a> [nlb\_security\_group\_id](#output\_nlb\_security\_group\_id) | n/a |
| <a name="output_nlb_zone_id"></a> [nlb\_zone\_id](#output\_nlb\_zone\_id) | n/a |
| <a name="output_privatelink_service_name"></a> [privatelink\_service\_name](#output\_privatelink\_service\_name) | Service name consumers reference in their aws\_vpc\_endpoint. Null unless enable\_privatelink is true. |
| <a name="output_privatelink_ssm_parameter_name"></a> [privatelink\_ssm\_parameter\_name](#output\_privatelink\_ssm\_parameter\_name) | SSM path where this service's PrivateLink service\_name is published, for cross-repo consumers. |
| <a name="output_zscaler_dns_record_fqdn"></a> [zscaler\_dns\_record\_fqdn](#output\_zscaler\_dns\_record\_fqdn) | FQDN of the cmscloud.local alias record, if created. |
<!-- END_TF_DOCS -->