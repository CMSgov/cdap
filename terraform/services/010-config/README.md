# CDAP Config Root Module

This root module is responsible for configuring the sops-enabled strategy for storing sensitive and nonsensitive configuration in AWS SSM Parameter Store.

## Local Development

Editing the local `values/test.sopsw.yaml` and `values/prod.sopsw.yaml` requires a SOPS Wrapper script distributed by CDAP's sops module used here.
From an authenticated shell, the wrapper can be installed using the example for `prod` below:

``` sh
# initialize the the config module for production
tofu init -backend-config="../../backends/cdap-prod.s3.tfbackend"

# create the  local `bin/sopsw` file; this typically only needs to be done once
tofu apply -target 'module.sops.local_file.sopsw[0]' -var=create_local_sops_wrapper=true

# Decrypt, open the values file using the $EDITOR set in your shell attempting `vim`, `nano`, and `vi` by default.
bin/sopsw -e values/prod.sopsw.yaml
```

**NOTE** The values file encodes which KMS keys are necessary for encryption/decryption. The shell must be authenticated with the right account and role in order to access the specified KMS keys.

<!-- BEGIN_TF_DOCS -->
<!--WARNING: GENERATED CONTENT with terraform-docs, e.g.
     'terraform-docs --config "$(git rev-parse --show-toplevel)/.terraform-docs.yml" .'
     Manually updating sections between TF_DOCS tags may be overwritten.
     See https://terraform-docs.io/user-guide/configuration/ for more information.
-->
## Providers

No providers.

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
| <a name="input_env"></a> [env](#input\_env) | The application environment (test, prod) | `string` | n/a | yes |
| <a name="input_create_local_sops_wrapper"></a> [create\_local\_sops\_wrapper](#input\_create\_local\_sops\_wrapper) | When `true`, creates sops wrapper file at `bin/sopsw`. | `bool` | `false` | no |

<!--WARNING: GENERATED CONTENT with terraform-docs, e.g.
     'terraform-docs --config "$(git rev-parse --show-toplevel)/.terraform-docs.yml" .'
     Manually updating sections between TF_DOCS tags may be overwritten.
     See https://terraform-docs.io/user-guide/configuration/ for more information.
-->
## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_platform"></a> [platform](#module\_platform) | github.com/CMSgov/cdap//terraform/modules/platform | 9389a80e100ec6cbdf0e2fc25123678c9156ff73 |
| <a name="module_sops"></a> [sops](#module\_sops) | github.com/CMSgov/cdap//terraform/modules/sops | 8874310 |

<!--WARNING: GENERATED CONTENT with terraform-docs, e.g.
     'terraform-docs --config "$(git rev-parse --show-toplevel)/.terraform-docs.yml" .'
     Manually updating sections between TF_DOCS tags may be overwritten.
     See https://terraform-docs.io/user-guide/configuration/ for more information.
-->
## Resources

No resources.

<!--WARNING: GENERATED CONTENT with terraform-docs, e.g.
     'terraform-docs --config "$(git rev-parse --show-toplevel)/.terraform-docs.yml" .'
     Manually updating sections between TF_DOCS tags may be overwritten.
     See https://terraform-docs.io/user-guide/configuration/ for more information.
-->
## Outputs

| Name | Description |
|------|-------------|
| <a name="output_edit"></a> [edit](#output\_edit) | n/a |
<!-- END_TF_DOCS -->
