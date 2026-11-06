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
| <a name="provider_aws"></a> [aws](#provider\_aws) | n/a |
| <a name="provider_tls"></a> [tls](#provider\_tls) | n/a |

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
| <a name="input_public_certificate"></a> [public\_certificate](#input\_public\_certificate) | Map of version to PEM-encoded CMS-signed certificate. | `map(string)` | `{}` | no |
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
| [aws_acm_certificate.public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate) | resource |
| [aws_ssm_parameter.csr](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_ssm_parameter.private_key](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [tls_cert_request.this](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/cert_request) | resource |
| [tls_private_key.this](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/private_key) | resource |

<!--WARNING: GENERATED CONTENT with terraform-docs, e.g.
     'terraform-docs --config "$(git rev-parse --show-toplevel)/.terraform-docs.yml" .'
     Manually updating sections between TF_DOCS tags may be overwritten.
     See https://terraform-docs.io/user-guide/configuration/ for more information.
-->
## Outputs

| Name | Description |
|------|-------------|
| <a name="output_csr_retrieval_instructions"></a> [csr\_retrieval\_instructions](#output\_csr\_retrieval\_instructions) | Instructions for retrieving the latest CSR and submitting to CMS. |
| <a name="output_public_cert_arns"></a> [public\_cert\_arns](#output\_public\_cert\_arns) | Map of version to ACM certificate ARN, for every version currently imported into ACM. Use the entry matching your target version when wiring up a listener. |
| <a name="output_public_cert_latest_version"></a> [public\_cert\_latest\_version](#output\_public\_cert\_latest\_version) | The highest version number currently declared in public\_certificate\_versions. Not necessarily imported yet — check public\_cert\_arns for that. |
| <a name="output_public_cert_pending_versions"></a> [public\_cert\_pending\_versions](#output\_public\_cert\_pending\_versions) | Versions with a CSR generated but no signed certificate material supplied yet. |
<!-- END_TF_DOCS -->