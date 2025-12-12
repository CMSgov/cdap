# Standards Child Module

This simple [child module](https://developer.hashicorp.com/terraform/language/modules#child-modules) comprises a limited number of data sources and outputs to facilitate standards adoption among resources that are largely managed by the CDAP team.

**NOTE** Ensure changes made to local.static_tags that are relevant to both **this** module and the `platform` module remain synchronized.

## Limitations

**This module is suitable for CDAP-managed resources only**

While this accommodates similar needs to that of the `platform` child module, it differs fundamentally in the following ways:
1. This avoids potential circular dependencies where the CDAP-defined _platform_ resources may be self-referential, e.g. the `platform` module depends on the CDAP-managed `security-groups` module : the `security-groups` module **should not** depend on the `platform` module.
2. The `platform` module only supports the emerging greenfield environments. For terraservices like `api-rds` that maintain a consistent code base between both legacy and greenfield environments, the `platform` module alone cannot provide the desired standards in these contexts.
3. Because we must continue to support the varied configuration among legacy environments, even if temporarily, this module cannot remain simple while making context-aware assumptions about the environments like the `platform` module does.

As a result, this module makes few assumptions and is limited to providing modest helper resources such as `default_tags`, `account_id`, `region_name`, and the CMS Hybrid Cloud default `ct-ado-poweruser-permissions-boundary-policy`.

## Example usage

```hcl
#Differentiating between `standards` and `platform` using `var.legacy`
module "standards" {
  count  = var.legacy ? 1 : 0
  source = "../../modules/standards"

  app         = var.app
  env         = var.env
  root_module = "https://github.com/CMSgov/cdap/tree/main/terraform/services/api-rds"
  service     = "api-rds"
}

module "platform" {
  count  = var.legacy ? 0 : 1
  source = "git::https://github.com/CMSgov/cdap.git//terraform/modules/platform?ref=80d2d5e500bcf8a069386dee677404033af7782c"

  app         = var.app
  env         = var.env
  root_module = "https://github.com/CMSgov/cdap/tree/main/terraform/services/api-rds"
  service     = "api-rds"
}

locals {
  app     = var.legacy ? module.standards[0].app : module.platform[0].app
  env     = var.legacy ? module.standards[0].env : module.platform[0].env
  service = var.legacy ? module.standards[0].service : module.platform[0].service
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
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.14.1 |
| <a name="provider_aws.secondary"></a> [aws.secondary](#provider\_aws.secondary) | 6.14.1 |

<!--WARNING: GENERATED CONTENT with terraform-docs, e.g.
     'terraform-docs --config "$(git rev-parse --show-toplevel)/.terraform-docs.yml" .'
     Manually updating sections between TF_DOCS tags may be overwritten.
     See https://terraform-docs.io/user-guide/configuration/ for more information.
-->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~>6 |

<!--WARNING: GENERATED CONTENT with terraform-docs, e.g.
     'terraform-docs --config "$(git rev-parse --show-toplevel)/.terraform-docs.yml" .'
     Manually updating sections between TF_DOCS tags may be overwritten.
     See https://terraform-docs.io/user-guide/configuration/ for more information.
-->
## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_app"></a> [app](#input\_app) | The short name for the delivery team or ADO. | `string` | n/a | yes |
| <a name="input_env"></a> [env](#input\_env) | The solution's environment name. | `string` | n/a | yes |
| <a name="input_root_module"></a> [root\_module](#input\_root\_module) | The full URL to the terraform module root at issue for this infrastructure | `string` | n/a | yes |
| <a name="input_service"></a> [service](#input\_service) | Service _or_ terraservice name. | `string` | n/a | yes |
| <a name="input_additional_tags"></a> [additional\_tags](#input\_additional\_tags) | Additional tags to merge into final default\_tags output | `map(string)` | `{}` | no |

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
| [aws_caller_identity.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy.permissions_boundary](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy) | data source |
| [aws_region.secondary](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [aws_region.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

<!--WARNING: GENERATED CONTENT with terraform-docs, e.g.
     'terraform-docs --config "$(git rev-parse --show-toplevel)/.terraform-docs.yml" .'
     Manually updating sections between TF_DOCS tags may be overwritten.
     See https://terraform-docs.io/user-guide/configuration/ for more information.
-->
## Outputs

| Name | Description |
|------|-------------|
| <a name="output_account_id"></a> [account\_id](#output\_account\_id) | Deprecated. Use `aws_caller_identity.account_id`. The AWS account ID associated with the current caller identity |
| <a name="output_app"></a> [app](#output\_app) | The short name for the delivery team or ADO. |
| <a name="output_aws_caller_identity"></a> [aws\_caller\_identity](#output\_aws\_caller\_identity) | The current data.aws\_caller\_identity object. |
| <a name="output_default_permissions_boundary"></a> [default\_permissions\_boundary](#output\_default\_permissions\_boundary) | Default permissions boundary [aws\_iam\_policy data source](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy#attribute-reference) |
| <a name="output_default_tags"></a> [default\_tags](#output\_default\_tags) | Map of tags for use in AWS provider block `default_tags`. Merges collection of standard tags with optional, user-specificed `additional_tags` |
| <a name="output_env"></a> [env](#output\_env) | The solution's application environment name. |
| <a name="output_is_ephemeral_env"></a> [is\_ephemeral\_env](#output\_is\_ephemeral\_env) | Returns true when environment is \_ephemeral\_, false when \_established\_ |
| <a name="output_parent_env"></a> [parent\_env](#output\_parent\_env) | The solution's source environment. For established environments this is equal to the environment's name |
| <a name="output_primary_region"></a> [primary\_region](#output\_primary\_region) | The primary data.aws\_region object from the current caller identity |
| <a name="output_secondary_region"></a> [secondary\_region](#output\_secondary\_region) | The secondary data.aws\_region object associated with the secondary region. |
| <a name="output_service"></a> [service](#output\_service) | The name of the current service or terraservice. |
<!-- END_TF_DOCS -->
