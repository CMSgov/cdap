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
## Requirements

No requirements.

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | 5.100.0 |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_sops"></a> [sops](#module\_sops) | github.com/CMSgov/cdap//terraform/modules/sops | 93820ca |
| <a name="module_standards"></a> [standards](#module\_standards) | github.com/CMSgov/cdap//terraform/modules/standards | 0bd3eeae6b03cc8883b7dbdee5f04deb33468260 |

## Resources

| Name | Type |
| ---- | ---- |
| [aws_kms_alias.primary](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/kms_alias) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_create_local_sops_wrapper"></a> [create\_local\_sops\_wrapper](#input\_create\_local\_sops\_wrapper) | When `true`, creates sops wrapper file at `bin/sopsw`. | `bool` | `false` | no |
| <a name="input_env"></a> [env](#input\_env) | The application environment (test, prod) | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_edit"></a> [edit](#output\_edit) | n/a |
<!-- END_TF_DOCS -->
