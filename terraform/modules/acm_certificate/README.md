Issues and manages ACM certificates for CMS platform services.
Supports three certificate paths: PCA-backed private certificates
(internal endpoints, Zscaler endpoints, mTLS sidecars) and
CMS-signed public certificates (*.cms.gov).


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

## Public Certificate Process

1. Apply with `public_domain_name` set but without `public_certificate`
   or `public_private_key`.
2. Retrieve the CSR from SSM:
   `/<app>/<env>/<service>/tls/v1/csr`
3. Submit the CSR to CMS for signing.
4. Encrypt the returned cert, key, and chain via SOPS.
5. Pass the SOPS-decrypted values into `public_certificate`,
   `public_private_key`, and `public_certificate_chain`.
6. Re-apply — the cert is imported into ACM automatically.



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
| <a name="provider_tls"></a> [tls](#provider\_tls) | >= 4.0 |

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
| <a name="input_enable_internal_endpoint"></a> [enable\_internal\_endpoint](#input\_enable\_internal\_endpoint) | Issue a PCA-backed certificate for the VPC-internal endpoint.<br/>Domain: <service>.<env>.<app>.internal.cms.gov<br/>Use for Lambda/ECS-to-ECS calls that do not need Zscaler or public access.<br/>Route 53 is NOT managed here. | `bool` | `false` | no |
| <a name="input_enable_mtls_sidecar"></a> [enable\_mtls\_sidecar](#input\_enable\_mtls\_sidecar) | Issue a PCA-backed certificate for mTLS between the ALB and the sidecar container.<br/>This certificate is NOT accessed by developers via Zscaler — it is used internally<br/>between the ALB and ECS sidecar only.<br/>Domain: <service>.<env>.<app>.internal.cms.gov (same as internal endpoint). | `bool` | `false` | no |
| <a name="input_enable_zscaler_endpoint"></a> [enable\_zscaler\_endpoint](#input\_enable\_zscaler\_endpoint) | Issue a PCA-backed certificate for the Zscaler-accessible endpoint.<br/>Domain: <service>.<env>.<app>.cmscloud.local<br/>Route 53 is NOT managed here — DNS for cmscloud.local is handled by CMS.<br/><br/>-------------------------------------------------------------------------<br/>CMS DOMAIN REGISTRATION — ACTION REQUIRED AFTER APPLY<br/>-------------------------------------------------------------------------<br/>After applying this module, submit a request to CMS to register:<br/>  <service>.<env>.<app>.cmscloud.local<br/>and point it at the ALB DNS name from the alb module output.<br/>Use the zscaler\_domain output from this module for the request.<br/>------------------------------------------------------------------------- | `bool` | `false` | no |
| <a name="input_pca_ram_resource_share_name"></a> [pca\_ram\_resource\_share\_name](#input\_pca\_ram\_resource\_share\_name) | Name of the AWS RAM resource share providing access to the shared Private CA. Required when enable\_internal\_endpoint or enable\_zscaler\_endpoint is true. | `string` | `"pace-ca-g1"` | no |
| <a name="input_public_certificate"></a> [public\_certificate](#input\_public\_certificate) | PEM-encoded CMS-signed public certificate. Include via SOPS if provided by CMS. Set null to defer import while awaiting CMS signing. | `string` | `null` | no |
| <a name="input_public_certificate_chain"></a> [public\_certificate\_chain](#input\_public\_certificate\_chain) | PEM-encoded certificate chain. Optional — include via SOPS if provided by CMS with the signed certificate. | `string` | `null` | no |
| <a name="input_public_certificate_versions"></a> [public\_certificate\_versions](#input\_public\_certificate\_versions) | Set of active certificate versions. Add a new version number to generate a new<br/>key and CSR for renewal without deleting the previous version's parameters.<br/>Example: [1] → initial; [1, 2] → renewal in progress; [2] → old version cleaned up. | `set(number)` | <pre>[<br/>  1<br/>]</pre> | no |
| <a name="input_public_domain_name"></a> [public\_domain\_name](#input\_public\_domain\_name) | Domain name for the public endpoint. Must end in .cms.gov.<br/>    -------------------------------------------------------------------------<br/>    PUBLIC CERTIFICATE PROCESS — ACTION REQUIRED BEFORE CERT IS ACTIVE<br/>    -------------------------------------------------------------------------<br/>    1. Run this module once without public\_certificate or public\_private\_key defined.<br/>    2. Follow output instructions to provide CMS with CSR in a zip file.<br/>    3. Once returned from CMS signed, encrypt the certificate, private key, and chain via SOPS.<br/>    4. Pass the sensitive values via SOPS into public\_certificate, public\_private\_key,<br/>       and public\_certificate\_chain at module instantiation.<br/>    5. Re-apply — the module imports the cert into ACM automatically. | `string` | `null` | no |
| <a name="input_public_private_key"></a> [public\_private\_key](#input\_public\_private\_key) | PEM-encoded private key for the public certificate. Include via SOPS if provided by CMS. Set null to defer. | `string` | `null` | no |

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
| [aws_acm_certificate.public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate) | resource |
| [aws_ssm_parameter.csr](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_ssm_parameter.private_key](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [tls_cert_request.this](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/cert_request) | resource |
| [tls_private_key.this](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/private_key) | resource |
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
| <a name="output_csr_retrieval_instructions"></a> [csr\_retrieval\_instructions](#output\_csr\_retrieval\_instructions) | Instructions for retrieving the latest CSR and submitting to CMS. |
| <a name="output_internal_domain"></a> [internal\_domain](#output\_internal\_domain) | FQDN of the internal endpoint. Use this as the Route 53 record name for DNS record to match exactly. |
| <a name="output_private_cert_arn"></a> [private\_cert\_arn](#output\_private\_cert\_arn) | ARN of the PCA-issued certificate covering the internal and/or zscaler domains. Use as the primary cert on the ALB HTTPS listener. |
| <a name="output_public_cert_arn"></a> [public\_cert\_arn](#output\_public\_cert\_arn) | ARN of the imported CMS-signed public certificate. Null if cert values have not yet been provided. |
| <a name="output_zscaler_domain"></a> [zscaler\_domain](#output\_zscaler\_domain) | n/a |
<!-- END_TF_DOCS -->