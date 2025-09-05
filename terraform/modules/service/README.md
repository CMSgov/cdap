# CDAP ECS Cluster Module 

## Usage
```hcl

```

<!-- BEGIN_TF_DOCS -->
## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.12.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_ecs_service.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_service) | resource |
| [aws_ecs_task_definition.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_task_definition) | resource |
| [aws_iam_role.ecs_task_execution_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.ecs_task_execution_policy_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_policy_document.ecs_task_execution_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cluster"></a> [cluster](#input\_cluster) | The ecs cluster hosting the service and task. | `any` | n/a | yes |
| <a name="input_container_definitions_filename"></a> [container\_definitions\_filename](#input\_container\_definitions\_filename) | Valid container definitions provided as a single valid JSON document. | `string` | n/a | yes |
| <a name="input_cpu"></a> [cpu](#input\_cpu) | Number of cpu units used by the task. | `number` | n/a | yes |
| <a name="input_desired_count"></a> [desired\_count](#input\_desired\_count) | Number of instances of the task definition to place and keep running. | `number` | `0` | no |
| <a name="input_family_name_override"></a> [family\_name\_override](#input\_family\_name\_override) | The desired family name for the ECS task definition.  If null will default to: {var.platform.env}-{var.platform.app}-{var.platform.service} | `any` | `null` | no |
| <a name="input_force_new_deployment"></a> [force\_new\_deployment](#input\_force\_new\_deployment) | Enable to delete a service even if it wasn't scaled down to zero tasks. | `bool` | `null` | no |
| <a name="input_load_balancers"></a> [load\_balancers](#input\_load\_balancers) | Load balancer(s) for use by the AWS ECS service. | <pre>list(object({<br/>    target_group_arn = string<br/>    container_name   = string<br/>    container_port   = number<br/>  }))</pre> | n/a | yes |
| <a name="input_memory"></a> [memory](#input\_memory) | Amount (in MiB) of memory used by the task. | `number` | n/a | yes |
| <a name="input_network_configurations"></a> [network\_configurations](#input\_network\_configurations) | Network configuration for the aws ecs service. | <pre>list(object({<br/>    subnets          = list(string)<br/>    assign_public_ip = string<br/>    security_groups  = list(string)<br/>  }))</pre> | n/a | yes |
| <a name="input_platform"></a> [platform](#input\_platform) | Object that describes standardized platform values. | `any` | n/a | yes |
| <a name="input_propagate_tags"></a> [propagate\_tags](#input\_propagate\_tags) | Determines whether to propagate the tags from the task definition to the Amazon EBS volume. | `string` | `"SERVICE"` | no |
| <a name="input_service_name_override"></a> [service\_name\_override](#input\_service\_name\_override) | Desired service name for the service tag on the aws ecs service.  Defaults to platform.service. | `string` | `null` | no |
| <a name="input_task_app_role_arn"></a> [task\_app\_role\_arn](#input\_task\_app\_role\_arn) | ARN of IAM role that allows your Amazon ECS container task to make calls to other AWS services. | `any` | n/a | yes |
| <a name="input_task_execution_role_arn"></a> [task\_execution\_role\_arn](#input\_task\_execution\_role\_arn) | ARN of the task execution role that the Amazon ECS container agent and the Docker daemon can assume.  Defaults to creation of a new role. | `string` | `null` | no |
| <a name="input_volumes"></a> [volumes](#input\_volumes) | EBS volumes to create for the ecs task definition. | `list(string)` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_aws_ecs_service"></a> [aws\_ecs\_service](#output\_aws\_ecs\_service) | The ecs service for the given inputs. |
| <a name="output_aws_ecs_task_definition"></a> [aws\_ecs\_task\_definition](#output\_aws\_ecs\_task\_definition) | The ecs task definition for the given inputs. |
<!-- END_TF_DOCS -->