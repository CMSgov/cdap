# CDAP Web Module

This module creates a CloudFront distribution including all necessary resources for operability except creation of certificates and CNAMES/domains.  
Modifications to the Cloudfront distribution name changes need to be registered with DNS management, currently managed by CMS.

A sample usage is as follows    :

```
module "platform" {
  source    = "github.com/CMSgov/cdap//terraform/modules/platform?ref=<hash>"
  providers = { aws = aws, aws.secondary = aws.secondary }

  app         = "bcda"
  env         = "prod"
  root_module = ""
  service     = "bcda"
}

resource "aws_acm_certificate" "cert" {
  domain_name       = "bcda.cms.gov"
  validation_method = "DNS"

  tags = {
    Environment = "test"
  }

  lifecycle {
    create_before_destroy = true
  }
}

module "web" {
  source = "../modules/web"
  domain_name = "bcda.cms.gov"
  platform        = module.platform
  
  redirects = {
    "/value1" = "/redirect1",
    "/value2" = "/redirect2"
  }
}
```

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
| <a name="input_domain_name"></a> [domain\_name](#input\_domain\_name) | An externally managed domain that points to this distribution. A matching ACM certificate must already be issued. | `string` | n/a | yes |
| <a name="input_platform"></a> [platform](#input\_platform) | Object representing the CDAP plaform module. | <pre>object({<br/>    app                   = string,<br/>    env                   = string,<br/>    splunk_logging_bucket = string<br/>  })</pre> | n/a | yes |
| <a name="input_redirects"></a> [redirects](#input\_redirects) | Map of redirects to be passed to the CloudFront redirects function. | `map(string)` | n/a | yes |
| <a name="input_allowed_ips_list"></a> [allowed\_ips\_list](#input\_allowed\_ips\_list) | Optional though needed for access. Generates an IP set that is attached to the firewall for access. | `list(any)` | `[]` | no |
| <a name="input_enabled"></a> [enabled](#input\_enabled) | Whether the distribution is enabled to accept end user requests for content. | `bool` | `true` | no |
| <a name="input_existing_ip_sets"></a> [existing\_ip\_sets](#input\_existing\_ip\_sets) | Optional. Attaches existing IP sets to the firewall. Favor a dedicated allowed list over existing IP sets. | `list(any)` | `[]` | no |
| <a name="input_s3_origin_id"></a> [s3\_origin\_id](#input\_s3\_origin\_id) | Variable to manage existing s3 origins without recreation. All new instances of this module can leave the default. | `string` | `"s3_origin"` | no |

<!--WARNING: GENERATED CONTENT with terraform-docs, e.g.
     'terraform-docs --config "$(git rev-parse --show-toplevel)/.terraform-docs.yml" .'
     Manually updating sections between TF_DOCS tags may be overwritten.
     See https://terraform-docs.io/user-guide/configuration/ for more information.
-->
## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_firewall"></a> [firewall](#module\_firewall) | ../firewall | n/a |
| <a name="module_origin_bucket"></a> [origin\_bucket](#module\_origin\_bucket) | ../bucket | n/a |

<!--WARNING: GENERATED CONTENT with terraform-docs, e.g.
     'terraform-docs --config "$(git rev-parse --show-toplevel)/.terraform-docs.yml" .'
     Manually updating sections between TF_DOCS tags may be overwritten.
     See https://terraform-docs.io/user-guide/configuration/ for more information.
-->
## Resources

| Name | Type |
|------|------|
| [aws_cloudfront_distribution.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_distribution) | resource |
| [aws_cloudfront_function.redirects](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_function) | resource |
| [aws_cloudfront_origin_access_control.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_origin_access_control) | resource |
| [aws_cloudfront_response_headers_policy.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_response_headers_policy) | resource |
| [aws_cloudwatch_log_delivery.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_delivery) | resource |
| [aws_cloudwatch_log_delivery_destination.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_delivery_destination) | resource |
| [aws_cloudwatch_log_delivery_source.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_delivery_source) | resource |
| [aws_s3_bucket_policy.allow_cloudfront_access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy) | resource |
| [aws_ssm_parameter.allowed_ip_list](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_wafv2_ip_set.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/wafv2_ip_set) | resource |
| [aws_acm_certificate.issued](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/acm_certificate) | data source |
| [aws_caller_identity.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.allow_cloudfront_access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_region.primary](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

<!--WARNING: GENERATED CONTENT with terraform-docs, e.g.
     'terraform-docs --config "$(git rev-parse --show-toplevel)/.terraform-docs.yml" .'
     Manually updating sections between TF_DOCS tags may be overwritten.
     See https://terraform-docs.io/user-guide/configuration/ for more information.
-->
## Outputs

| Name | Description |
|------|-------------|
| <a name="output_distribution"></a> [distribution](#output\_distribution) | n/a |
<!-- END_TF_DOCS -->