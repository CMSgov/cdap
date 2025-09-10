# CDAP ECS Cluster Module 

## Usage
```hcl
container_definitions_example_file:
container_definitions.json
[
{
  "name": "first",
  "image": "service-first",
  "cpu": 10,
  "memory": 512,
  "essential": true,
  "portMappings": [
    {
      "containerPort": 80,
      "hostPort": 80
    }
  ]
},
{
"name": "second",
"image": "service-second",
"cpu": 10,
"memory": 256,
"essential": true,
"portMappings": [
{
"containerPort": 443,
"hostPort": 443
}
]
}
]



module "platform" {
    source    = "github.com/CMSgov/cdap//terraform/modules/platform?ref=ff2ef539fb06f2c98f0e3ce0c8f922bdacb96d66"
    providers = { aws = aws, aws.secondary = aws.secondary }
    
    app         = "ab2d"
    env         = "dev"
    root_module = "https://github.com/CMSgov/ab2d/tree/main/ops/services/20-microservices"
    service     = "contracts"
    ssm_root_map = {
        common = "/ab2d/${local.env}/common"
        core   = "/ab2d/${local.env}/core"
    }
}

module "cluster" {
    source   = "github.com/CMSgov/cdap//terraform/modules/cluster?ref=<hash>"
    platform = module.platform
}

module "service" {
    cluster = module.cluster.this.id
    container_definitions_filename = "container_definitions.json" # See file description above.
    cpu = 1048
    desired_count = 1  # Optional - how many instances to keep running after task is complete.  Default is 0.
    family_name_override = "microservice" # Optional - The family name for the ECS task definition.  If null will default to: {var.platform.env}-{var.platform.app}-{var.platform.service}
    force_new_deployment = true #Optional - Set to true to delete a service even if it wasn't scaled down to zero tasks. Default is false.
    load_balancers = [{
        target_group_arn = "this is an arn"
        container_name = "this is the container name"
        container_port = 3000
        },
        {
        target_group_arn = "this is another arn"
        container_name = "this is the other container name"
        container_port = 3001
    }]
    memory = 2048
    network_configurations = [{
        subnets = ["subnet-a", "subnet-b"]
        assign_public_ip = false
        security_groups = ["sg-a", "sg-b"]
    }]
    propagate_tags = "SERVICE"
    # SERVICE: Tags defined on the aws_ecs_service resource itself will be propagated to the tasks. Default value.
    # TASK_DEFINITION: Tags defined on the aws_ecs_task_definition resource will be propagated to the tasks.
    service_name_override = "my_test_service" # Optional - Desired service name for the service tag on the aws ecs service.  Defaults to platform.service.
    task_execution_role_arn = "this_is_an_iam_role_arn" #Optional - ARN of the task execution role that the Amazon ECS container agent and the Docker daemon can assume.  Defaults to creation of a new role.
    task_app_role_arn = "this_is_an_iam_role_arn"  # ARN of IAM role that allows your Amazon ECS container task to make calls to other AWS services.
    volumes = ["/tmp", "/log"] # List of EBS volume names to create for the ecs task definition.
}   

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