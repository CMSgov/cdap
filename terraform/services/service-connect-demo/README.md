## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | 5.81.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 5.81.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_backend_service"></a> [backend\_service](#module\_backend\_service) | github.com/CMSgov/cdap//terraform/modules/service | plt-1448_test_service_connect |
| <a name="module_cluster"></a> [cluster](#module\_cluster) | github.com/CMSgov/cdap//terraform/modules/cluster | plt-1448_test_service_connect |
| <a name="module_platform"></a> [platform](#module\_platform) | github.com/CMSgov/cdap//terraform/modules/platform | plt-1448_test_service_connect |

## Resources

| Name | Type |
|------|------|
| [aws_iam_role.ecs_task_execution_role](https://registry.terraform.io/providers/hashicorp/aws/5.81.0/docs/resources/iam_role) | resource |
| [aws_iam_role.ecs_task_role](https://registry.terraform.io/providers/hashicorp/aws/5.81.0/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.ecs_task_policy](https://registry.terraform.io/providers/hashicorp/aws/5.81.0/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy_attachment.ecs_task_execution_role_policy](https://registry.terraform.io/providers/hashicorp/aws/5.81.0/docs/resources/iam_role_policy_attachment) | resource |
| [aws_lb.backend](https://registry.terraform.io/providers/hashicorp/aws/5.81.0/docs/resources/lb) | resource |
| [aws_lb_listener.backend](https://registry.terraform.io/providers/hashicorp/aws/5.81.0/docs/resources/lb_listener) | resource |
| [aws_lb_target_group.backend](https://registry.terraform.io/providers/hashicorp/aws/5.81.0/docs/resources/lb_target_group) | resource |
| [aws_security_group.ecs_tasks](https://registry.terraform.io/providers/hashicorp/aws/5.81.0/docs/resources/security_group) | resource |
| [aws_security_group.load_balancer](https://registry.terraform.io/providers/hashicorp/aws/5.81.0/docs/resources/security_group) | resource |
| [aws_vpc.selected](https://registry.terraform.io/providers/hashicorp/aws/5.81.0/docs/data-sources/vpc) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | AWS region | `string` | `"us-east-1"` | no |
| <a name="input_private_subnet_ids"></a> [private\_subnet\_ids](#input\_private\_subnet\_ids) | List of private subnet IDs for ECS tasks | `list(string)` | n/a | yes |
| <a name="input_public_subnet_ids"></a> [public\_subnet\_ids](#input\_public\_subnet\_ids) | List of private subnet IDs for ECS tasks | `list(string)` | n/a | yes |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | VPC ID where ECS cluster will be deployed | `string` | n/a | yes |

## Outputs

No outputs.
