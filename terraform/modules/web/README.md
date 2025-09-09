# CDAP Web Module

This module creates a CloudFront distribution and origin access control intended for use with the AB2D, BCDA and DPC static websites. A sample minimal calling configuration is as follows:

```
module "platform" {
  source    = "../modules/platform"
  providers = { aws = aws, aws.secondary = aws.secondary }

  app         = "bcda"
  env         = "prod"
  root_module = ""
  service     = "bcda"
}

module web_acl {
  source  = "../modules/firewall"

  app           = module.platform.app
  content_type  = "APPLICATION_JSON"
  env           = module.platform.env
  name          = "samplewebacl"
  scope         = "CLOUDFRONT"
}

module origin_bucket {
  source  = "../modules/bucket"
  
  app   = module.platform.app
  env   = module.platform.env
  name  = "origin"
}

module logging_bucket {
  source  = "../modules/bucket"
  
  app   = module.platform.app
  env   = module.platform.env
  name  = "logging"
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

  certificate     = aws_acm_certificate.cert
  logging_bucket  = module.logging_bucket
  origin_bucket   = module.origin_bucket
  platform        = module.platform
  web_acl         = module.web_acl
  
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
| <a name="input_logging_bucket"></a> [logging\_bucket](#input\_logging\_bucket) | Object representing the logging S3 bucket. | `any` | n/a | yes |
| <a name="input_origin_bucket"></a> [origin\_bucket](#input\_origin\_bucket) | Object representing the origin S3 bucket. | `any` | n/a | yes |
| <a name="input_platform"></a> [platform](#input\_platform) | Object representing the CDAP plaform module. | `any` | n/a | yes |
| <a name="input_web_acl"></a> [web\_acl](#input\_web\_acl) | Object representing the associated WAF acl. | `any` | n/a | yes |
| <a name="input_certificate"></a> [certificate](#input\_certificate) | Object representing the website certificate. | <pre>object({<br/>    arn         = string<br/>    domain_name = string<br/>  })</pre> | `null` | no |
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
| [aws_cloudwatch_log_delivery.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_delivery) | resource |
| [aws_cloudwatch_log_delivery_destination.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_delivery_destination) | resource |
| [aws_cloudwatch_log_delivery_source.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_delivery_source) | resource |

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