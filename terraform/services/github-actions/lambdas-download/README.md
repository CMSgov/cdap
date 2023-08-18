# Wrapper to download lambdas for github runners

Download Lambda distribution from the GitHub release.

```bash
terraform init
terraform apply -var=module_version=<VERSION>
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1 |

## Providers

No providers.

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_lambdas"></a> [lambdas](#module\_lambdas) | github.com/philips-labs/terraform-aws-github-runner//modules/download-lambda | n/a |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_module_version"></a> [module\_version](#input\_module\_version) | Module release version. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_files"></a> [files](#output\_files) | n/a |
<!-- END_TF_DOCS -->
