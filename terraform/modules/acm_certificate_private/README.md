Issues and manages private ACM certificates for CMS platform services.
Supports three certificate paths for PCA-backed private certificates
(internal endpoints, Zscaler endpoints, mTLS sidecars).

## Design Decisions

- **Explicit instantiation required.** This module is never called
  internally by `ecs_service`, `alb`, or other consumer modules.
  All ACM certificates are top-level resources in the caller stack,
  making them easy to audit via `tofu state list`.
- **mTLS passphrase is ephemeral.** The mTLS sidecar generates a
  one-time passphrase in memory at container startup, uses it to
  decrypt the exported cert bundle to tmpfs, and discards it.
  No passphrase is stored in SSM or state.
- **One private cert, multiple consumers.** When both
  `enable_internal_endpoint` and `enable_mtls_sidecar` are true,
  both outputs resolve to the same underlying cert. The separate
  output names exist for caller clarity only.

## Zscaler Registration — Action Required

Setting enable_zscaler_endpoint = true does not automatically register the domain. After applying, submit a DNS registration request to the CMS network team for:

<service>.<env>.<app>.cmscloud.local


<!-- BEGIN_TF_DOCS -->
<!--WARNING: GENERATED CONTENT with terraform-docs, e.g.
     'terraform-docs --config "$(git rev-parse --show-toplevel)/.terraform-docs.yml" .'
     Manually updating sections between TF_DOCS tags may be overwritten.
     See https://terraform-docs.io/user-guide/configuration/ for more information.
-->
## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 5.0 |

<!--WARNING: GENERATED CONTENT with terraform-docs, e.g.
     'terraform-docs --config "$(git rev-parse --show-toplevel)/.terraform-docs.yml" .'
     Manually updating sections between TF_DOCS tags may be overwritten.
     See https://terraform-docs.io/user-guide/configuration/ for more information.
-->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.6.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.0 |
| <a name="requirement_tls"></a> [tls](#requirement\_tls) | >= 4.0 |

<!--WARNING: GENERATED CONTENT with terraform-docs, e.g.
     'terraform-docs --config "$(git rev-parse --show-toplevel)/.terraform-docs.yml" .'
     Manually updating sections between TF_DOCS tags may be overwritten.
     See https://terraform-docs.io/user-guide/configuration/ for more information.
-->
## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_platform"></a> [platform](#input\_platform) | Object representing the CDAP platform module. | <pre>object({<br/>    app            = string<br/>    env            = string<br/>    primary_region = object({ name = string })<br/>    service        = string<br/>    kms_alias_primary = object({<br/>      target_key_arn = string<br/>    })<br/>  })</pre> | n/a | yes |
| <a name="input_domain_name"></a> [domain\_name](#input\_domain\_name) | Subdomain string. If left empty, defaults to platform service name. | `string` | `null` | no |
| <a name="input_enable_internal_endpoint"></a> [enable\_internal\_endpoint](#input\_enable\_internal\_endpoint) | Issue a PCA-backed certificate for the VPC-internal endpoint.<br/>Domain: <service>.<env>.<app>.internal.cms.gov<br/>Use for Lambda/ECS-to-ECS calls that do not need Zscaler or public access.<br/>Route 53 is NOT managed here. | `bool` | `false` | no |
| <a name="input_enable_mtls_sidecar"></a> [enable\_mtls\_sidecar](#input\_enable\_mtls\_sidecar) | Issue a PCA-backed certificate for mTLS between an NLB and the sidecar container.<br/>This certificate is NOT accessed by developers via Zscaler — it is used internally<br/>between the ALB and ECS sidecar only.<br/>Domain: <service>.<env>.<app>.internal.cms.gov (same as internal endpoint). | `bool` | `false` | no |
| <a name="input_enable_zscaler_endpoint"></a> [enable\_zscaler\_endpoint](#input\_enable\_zscaler\_endpoint) | Issue a PCA-backed certificate for the Zscaler-accessible endpoint.<br/>Domain: <service>.<env>.<app>.cmscloud.local<br/>Route 53 is NOT managed here — DNS for cmscloud.local is handled by CMS.<br/><br/>-------------------------------------------------------------------------<br/>CMS DOMAIN REGISTRATION — ACTION REQUIRED AFTER APPLY<br/>-------------------------------------------------------------------------<br/>After applying this module, submit a request to CMS to register:<br/>  <service>.<env>.<app>.cmscloud.local<br/>and point it at the ALB DNS name from the alb module output.<br/>Use the zscaler\_domain output from this module for the request.<br/>------------------------------------------------------------------------- | `bool` | `false` | no |
| <a name="input_pca_ram_resource_share_name"></a> [pca\_ram\_resource\_share\_name](#input\_pca\_ram\_resource\_share\_name) | Name of the AWS RAM resource share providing access to the shared Private CA. Required when enable\_internal\_endpoint or enable\_zscaler\_endpoint is true. | `string` | `"pace-ca-g1"` | no |

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
| [aws_acm_certificate.private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate) | resource |
| [aws_ram_resource_share.pace_ca](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ram_resource_share) | data source |
| [aws_route53_zone.internal](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/route53_zone) | data source |
| [aws_route53_zone.zscaler](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/route53_zone) | data source |

<!--WARNING: GENERATED CONTENT with terraform-docs, e.g.
     'terraform-docs --config "$(git rev-parse --show-toplevel)/.terraform-docs.yml" .'
     Manually updating sections between TF_DOCS tags may be overwritten.
     See https://terraform-docs.io/user-guide/configuration/ for more information.
-->
## Outputs

| Name | Description |
|------|-------------|
| <a name="output_internal_domain"></a> [internal\_domain](#output\_internal\_domain) | FQDN of the internal endpoint. Use this as the Route 53 record name for DNS record to match exactly. |
| <a name="output_private_cert_arn"></a> [private\_cert\_arn](#output\_private\_cert\_arn) | ARN of the PCA-issued certificate covering the internal and/or zscaler domains. Use as the primary cert on the ALB HTTPS listener. |
| <a name="output_zscaler_domain"></a> [zscaler\_domain](#output\_zscaler\_domain) | n/a |
<!-- END_TF_DOCS -->