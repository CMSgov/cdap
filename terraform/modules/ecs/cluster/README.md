<!-- BEGIN_TF_DOCS -->
## Requirements

A module to provide a standard template for new ecs clusters.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | n/a |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_platform"></a> [platform](#module\_platform) | github.com/CMSgov/cdap//terraform/modules/platform | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_ecs_cluster.ecs_cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_cluster) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_app"></a> [app](#input\_app) | The application name (ab2d, bcda, dpc) | `string` | n/a | yes |
| <a name="input_cluster_kms_master_key_id"></a> [cluster\_kms\_master\_key\_id](#input\_cluster\_kms\_master\_key\_id) | kms\_master\_key\_id to be used by the ecs cluster and fargate\_ephemeral\_storage\_kms\_key\_id. | `string` | n/a | yes |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Name of the ecs cluster. | `string` | n/a | yes |
| <a name="input_env"></a> [env](#input\_env) | The application environment (dev, test, sandbox, prod) | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_name"></a> [name](#output\_name) | Name for the ecs cluster |
<!-- END_TF_DOCS -->