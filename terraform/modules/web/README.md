# CDAP Web Module

This module creates a CloudFront distribution and origin access control intended for use with the AB2D, BCDA and DPC static websites. A sample minimal calling configuration is as follows:

```
module web_acl {
  source  = "../modules/firewall"

  app           = "bcda"
  content_type  = "APPLICATION_JSON"
  env           = "test"
  name          = "samplewebacl"
  scope         = "CLOUDFRONT"
}

module bucket {
  source  = "../modules/bucket"
  name    = "test"
}

resource "aws_acm_certificate" "cert" {
  domain_name       = "stage.bcda.cms.gov"
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

  bucket      = module.bucket
  certificate = aws_acm_certificate.cert
  web_acl     = module.web_acl
  
  viewer_request_function_list = [
    {
      code    = "test_code1"
      comment = "test_comment1"
      name    = "test_name1"
      runtime = "cloudfront-js-2.0"
    },
    {
      code    = "test_code2"
      comment = "test_comment2"
      name    = "test_name2"
      runtime = "cloudfront-js-2.0"
    }
  ]
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
| <a name="input_bucket"></a> [bucket](#input\_bucket) | Object representing the origin S3 bucket. | `map` | n/a | yes |
| <a name="input_certificate"></a> [certificate](#input\_certificate) | Object representing the website certificate. | <pre>object({<br/>    arn         = string<br/>    domain_name = string<br/>  })</pre> | n/a | yes |
| <a name="input_web_acl"></a> [web\_acl](#input\_web\_acl) | Object representing the associated WAF acl. | `map` | n/a | yes |
| <a name="input_cache_policy_id"></a> [cache\_policy\_id](#input\_cache\_policy\_id) | Default cache behavior for this distribution. | `string` | `null` | no |
| <a name="input_enabled"></a> [enabled](#input\_enabled) | Whether the distribution is enabled to accept end user requests for content. | `bool` | `true` | no |
| <a name="input_viewer_request_function_list"></a> [viewer\_request\_function\_list](#input\_viewer\_request\_function\_list) | Optional list of viewer request function definitions to associate with the distribution. | <pre>list(object({<br/>    code        = string<br/>    comment     = string<br/>    name        = string<br/>    runtime     = string<br/>  }))</pre> | `[]` | no |

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
| [aws_cloudfront_distribution.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_distribution) | resource |
| [aws_cloudfront_function.viewer_request](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_function) | resource |
| [aws_cloudfront_origin_access_control.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_origin_access_control) | resource |

<!--WARNING: GENERATED CONTENT with terraform-docs, e.g.
     'terraform-docs --config "$(git rev-parse --show-toplevel)/.terraform-docs.yml" .'
     Manually updating sections between TF_DOCS tags may be overwritten.
     See https://terraform-docs.io/user-guide/configuration/ for more information.
-->
## Outputs

| Name | Description |
|------|-------------|
| <a name="output_distribution_arn"></a> [distribution\_arn](#output\_distribution\_arn) | n/a |
| <a name="output_distribution_domain_name"></a> [distribution\_domain\_name](#output\_distribution\_domain\_name) | n/a |
<!-- END_TF_DOCS -->