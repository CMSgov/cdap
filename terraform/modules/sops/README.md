# SOPS Child Module

This module facilitates adoption of a terraform/tofu infrastructure-as-code strategy for managing both secure and nonsecure configuration values in AWS SSM Parameter Store with the following:
* distributes a wrapper script `sopsw` for getsops.io that helps us avoid:
  * frequent, largely meaningless git merge conflicts for this specific getsops.io use-case
  * needlessly oversharing semi-sensitive AWS Account IDs
* provides a loose framework for securely managing configuration under a single root module for multiple environments through environment-specific _"sopsw.yaml"_ files
* supports ephemeral environments that are based on a given enduring _parent environment_

## Dependencies
The distributed `sopsw` wrapper script requires the following to be installed for locally editing sopsw files:
* awscli
* getsops.io
* yq
* envsubst

## Example Usage

``` hcl
# Ensure `ref` in the following line is pinned to something static
# e.g. a known branch, commit hash, or tag from **this repository**
module "platform" {
  source    = "github.com/CMSgov/cdap//terraform/modules/platform?ref=<hash|tag|branch>"
  providers = { aws = aws, aws.secondary = aws.secondary }

  app         = var.app
  env         = var.env
  root_module = "https://github.com/CMSgov/ab2d/tree/main/ops/services/10-config"
  service     = var.service
}

# Ensure `ref` in the following line is pinned to something static
# e.g. a known branch, commit hash, or tag from **this repository**
module "sops" {
  source = "github.com/CMSgov/cdap//terraform/modules/sops?ref=<hash|tag|branch>"

  platform = module.platform
}


output "edit" {
  value = module.sops.sopsw
}
```
SOPS documentation:  https://confluence.cms.gov/spaces/ODI/pages/1353352386/SOPS+for+Secrets+Management

<!-- TODO: Write standards, examples, etc for usage of this module -->

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
| <a name="provider_external"></a> [external](#provider\_external) | n/a |
| <a name="provider_local"></a> [local](#provider\_local) | n/a |

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
| <a name="input_platform"></a> [platform](#input\_platform) | Object that describes standardized platform values. | `any` | n/a | yes |
| <a name="input_create_local_sops_wrapper"></a> [create\_local\_sops\_wrapper](#input\_create\_local\_sops\_wrapper) | Specify whether to create the script for localling editing the wrapped, sops 'sopsw' values file. | `string` | `true` | no |
| <a name="input_sopsw_parent_yaml_file"></a> [sopsw\_parent\_yaml\_file](#input\_sopsw\_parent\_yaml\_file) | Override. With `var.sopsw_values_file_extension`, specifies the wrapped, sops 'sopsw' values file base name. Defaults to `${local.parent_env}.${var.sopsw_values_file_extension}`, e.g. `prod.sopsw.yaml`. | `string` | `null` | no |
| <a name="input_sopsw_values_dir"></a> [sopsw\_values\_dir](#input\_sopsw\_values\_dir) | Override. Path to the root module's directory where the wrapped sops 'sopsw' values files directory. Defaults to `./values/` within the root module. | `string` | `null` | no |
| <a name="input_sopsw_values_file_extension"></a> [sopsw\_values\_file\_extension](#input\_sopsw\_values\_file\_extension) | Override. File extension of the wrapped sops 'sopsw' values file. | `string` | `"sopsw.yaml"` | no |

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
| [aws_ssm_parameter.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [local_file.sopsw](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [external_external.decrypted_sops](https://registry.terraform.io/providers/hashicorp/external/latest/docs/data-sources/external) | data source |

<!--WARNING: GENERATED CONTENT with terraform-docs, e.g.
     'terraform-docs --config "$(git rev-parse --show-toplevel)/.terraform-docs.yml" .'
     Manually updating sections between TF_DOCS tags may be overwritten.
     See https://terraform-docs.io/user-guide/configuration/ for more information.
-->
## Outputs

| Name | Description |
|------|-------------|
| <a name="output_sopsw"></a> [sopsw](#output\_sopsw) | When `var.create_local_sops_wrapper` true, output tui/cli command for editing the current environment's wrapped, sops 'sopsw' values file. |
<!-- END_TF_DOCS -->
