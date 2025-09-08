<!-- BEGIN_TF_DOCS -->
## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 5.100.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_ecs_cluster.ecs_cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_cluster) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_app"></a> [app](#input\_app) | The application name (ab2d, bcda, dpc) | `string` | n/a | yes |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Name of the ecs cluster. | `string` | n/a | yes |
| <a name="input_env"></a> [env](#input\_env) | The application environment (dev, test, sandbox, prod) | `string` | n/a | yes |
| <a name="input_platform"></a> [platform](#input\_platform) | Object that describes standardized platform values. | `any` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_id"></a> [id](#output\_id) | ID for the ecs cluster |
| <a name="output_name"></a> [name](#output\_name) | Name for the ecs cluster |
<!-- END_TF_DOCS -->