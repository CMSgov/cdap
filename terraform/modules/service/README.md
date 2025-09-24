# CDAP ECS Cluster Module

## Usage
```hcl
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
  container_environment = [{
    name = "ENV_VAR_NAME"
    value = "EXAMPLE"
  }]
  container_secrets = [{
    name = "SECRET_NAME"
    valueFrom = "EXAMPLE"
  }]

  cpu = 1048
  desired_count = 1  # Optional - how many instances to keep running after task is complete.  Default is 0.
  force_new_deployment = true #Optional - Set to true to delete a service even if it wasn't scaled down to zero tasks. Default is false.
  image = "image_name_from_ecr"
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
  mount_points = [{
    containerPath = "/var" # Optional
    readOnly      = true # Optional
    sourceVolume  = "example" # Optional
  }]
  network_configurations = [{
    subnets = ["subnet-a", "subnet-b"]
    assign_public_ip = false
    security_groups = ["sg-a", "sg-b"]
  }]
  port_mappings = [{
    appProtocol        = "tcp" # Optional
    containerPort      = "30030" # Optional
    containerPortRange = "30000:40000" # Optional
    hostPort           = "8080" # Optional
    name               = "portName" # Optional
    protocol           = "tcp" # Optional
  }]
  propagate_tags = "SERVICE"
  # SERVICE: Tags defined on the aws_ecs_service resource itself will be propagated to the tasks. Default value.
  # TASK_DEFINITION: Tags defined on the aws_ecs_task_definition resource will be propagated to the tasks.
  service_name_override = "my_test_service" # Optional - Desired service name for the service tag on the aws ecs service.  Defaults to platform.service.
  execution_role_arn = "this_is_an_iam_role_arn" #Optional - ARN of the task execution role that the Amazon ECS container agent and the Docker daemon can assume.  Defaults to creation of a new role.
  app_role_arn = "this_is_an_iam_role_arn"  # ARN of IAM role that allows your Amazon ECS container task to make calls to other AWS services.
  volume = [{
    name      = "my-host-volume"
    host_path = "/var/lib/mydata"
  },
    {  name = "my-efs-volume"
    [{
      file_system_id = "fs-12345678"
      root_directory = "/app_data"
      authorization_config = [{
        iam = "ENABLED"
      }]
    }]
    }]
}


```

<!-- BEGIN_TF_DOCS -->
## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.13.0 |

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
| <a name="input_cloudwatch_log_group_class"></a> [cloudwatch\_log\_group\_class](#input\_cloudwatch\_log\_group\_class) | Specified the log class of the log group. Possible values are: `STANDARD` or `INFREQUENT_ACCESS` | `string` | `null` | no |
| <a name="input_cloudwatch_log_group_kms_key_id"></a> [cloudwatch\_log\_group\_kms\_key\_id](#input\_cloudwatch\_log\_group\_kms\_key\_id) | If a KMS Key ARN is set, this key will be used to encrypt the corresponding log group. Please be sure that the KMS Key has an appropriate key policy (https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/encrypt-log-data-kms.html) | `string` | `null` | no |
| <a name="input_cloudwatch_log_group_name"></a> [cloudwatch\_log\_group\_name](#input\_cloudwatch\_log\_group\_name) | Custom name of CloudWatch log group for a service associated with the container definition | `string` | `null` | no |
| <a name="input_cloudwatch_log_group_retention_in_days"></a> [cloudwatch\_log\_group\_retention\_in\_days](#input\_cloudwatch\_log\_group\_retention\_in\_days) | Number of days to retain log events. Set to `0` to keep logs indefinitely | `number` | `14` | no |
| <a name="input_cloudwatch_log_group_use_name_prefix"></a> [cloudwatch\_log\_group\_use\_name\_prefix](#input\_cloudwatch\_log\_group\_use\_name\_prefix) | Determines whether the log group name should be used as a prefix | `bool` | `false` | no |
| <a name="input_cluster"></a> [cluster](#input\_cluster) | The ecs cluster hosting the service and task. | `any` | n/a | yes |
| <a name="input_container_environment"></a> [container\_environment](#input\_container\_environment) | The environment variables to pass to the container | <pre>list(object({<br/>    name  = string<br/>    value = string<br/>  }))</pre> | `null` | no |
| <a name="input_container_secrets"></a> [container\_secrets](#input\_container\_secrets) | The secrets to pass to the container. For more information, see [Specifying Sensitive Data](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/specifying-sensitive-data.html) in the Amazon Elastic Container Service Developer Guide | <pre>list(object({<br/>    name      = string<br/>    valueFrom = string<br/>  }))</pre> | `null` | no |
| <a name="input_cpu"></a> [cpu](#input\_cpu) | Number of cpu units used by the task. | `number` | n/a | yes |
| <a name="input_create_cloudwatch_log_group"></a> [create\_cloudwatch\_log\_group](#input\_create\_cloudwatch\_log\_group) | Determines whether a log group is created by this module. If not, AWS will automatically create one if logging is enabled | `bool` | `true` | no |
| <a name="input_desired_count"></a> [desired\_count](#input\_desired\_count) | Number of instances of the task definition to place and keep running. | `number` | `0` | no |
| <a name="input_enable_cloudwatch_logging"></a> [enable\_cloudwatch\_logging](#input\_enable\_cloudwatch\_logging) | Determines whether CloudWatch logging is configured for this container definition. Set to `false` to use other logging drivers | `bool` | `true` | no |
| <a name="input_family_name_override"></a> [family\_name\_override](#input\_family\_name\_override) | The desired family name for the ECS task definition.  If null will default to: {var.platform.env}-{var.platform.app}-{var.platform.service} | `any` | `null` | no |
| <a name="input_force_new_deployment"></a> [force\_new\_deployment](#input\_force\_new\_deployment) | When *changed* to `true`, trigger a new deployment of the ECS Service even when a deployment wouldn't otherwise be triggered by other changes. **Note**: This has no effect when the value is `false`, changed to `false`, or set to `true` between consecutive applies. | `bool` | `false` | no |
| <a name="input_image"></a> [image](#input\_image) | The image used to start a container. This string is passed directly to the Docker daemon. By default, images in the Docker Hub registry are available. Other repositories are specified with either `repository-url/image:tag` or `repository-url/image@digest` | `string` | `null` | no |
| <a name="input_load_balancers"></a> [load\_balancers](#input\_load\_balancers) | Load balancer(s) for use by the AWS ECS service. | <pre>list(object({<br/>    target_group_arn = string<br/>    container_name   = string<br/>    container_port   = number<br/>  }))</pre> | n/a | yes |
| <a name="input_memory"></a> [memory](#input\_memory) | Amount (in MiB) of memory used by the task. | `number` | n/a | yes |
| <a name="input_mount_points"></a> [mount\_points](#input\_mount\_points) | The mount points for data volumes in your container | <pre>list(object({<br/>    containerPath = optional(string)<br/>    readOnly      = optional(bool)<br/>    sourceVolume  = optional(string)<br/>  }))</pre> | `null` | no |
| <a name="input_network_configurations"></a> [network\_configurations](#input\_network\_configurations) | Network configuration for the aws ecs service. | <pre>list(object({<br/>    subnets          = list(string)<br/>    assign_public_ip = string<br/>    security_groups  = list(string)<br/>  }))</pre> | n/a | yes |
| <a name="input_platform"></a> [platform](#input\_platform) | Object that describes standardized platform values. | `any` | n/a | yes |
| <a name="input_port_mappings"></a> [port\_mappings](#input\_port\_mappings) | The list of port mappings for the container. Port mappings allow containers to access ports on the host container instance to send or receive traffic. For task definitions that use the awsvpc network mode, only specify the containerPort. The hostPort can be left blank or it must be the same value as the containerPort | <pre>list(object({<br/>    appProtocol        = optional(string)<br/>    containerPort      = optional(number)<br/>    containerPortRange = optional(string)<br/>    hostPort           = optional(number)<br/>    name               = optional(string)<br/>    protocol           = optional(string)<br/>  }))</pre> | `null` | no |
| <a name="input_propagate_tags"></a> [propagate\_tags](#input\_propagate\_tags) | Determines whether to propagate the tags from the task definition to the Amazon EBS volume. | `string` | `"SERVICE"` | no |
| <a name="input_service_name_override"></a> [service\_name\_override](#input\_service\_name\_override) | Desired service name for the service tag on the aws ecs service.  Defaults to platform.service. | `string` | `null` | no |
| <a name="input_task_app_role_arn"></a> [task\_app\_role\_arn](#input\_task\_app\_role\_arn) | ARN of IAM role that allows your Amazon ECS container task to make calls to other AWS services. | `any` | n/a | yes |
| <a name="input_task_execution_role_arn"></a> [task\_execution\_role\_arn](#input\_task\_execution\_role\_arn) | ARN of the task execution role that the Amazon ECS container agent and the Docker daemon can assume.  Defaults to creation of a new role. | `string` | `null` | no |
| <a name="input_volume"></a> [volume](#input\_volume) | Configuration block for volumes that containers in your task may use | <pre>map(object({<br/>    configure_at_launch = optional(bool)<br/>    docker_volume_configuration = optional(object({<br/>      autoprovision = optional(bool)<br/>      driver        = optional(string)<br/>      driver_opts   = optional(map(string))<br/>      labels        = optional(map(string))<br/>      scope         = optional(string)<br/>    }))<br/>    efs_volume_configuration = optional(object({<br/>      authorization_config = optional(object({<br/>        access_point_id = optional(string)<br/>        iam             = optional(string)<br/>      }))<br/>      file_system_id          = string<br/>      root_directory          = optional(string)<br/>      transit_encryption      = optional(string)<br/>      transit_encryption_port = optional(number)<br/>    }))<br/>    host_path = optional(string)<br/>    name      = optional(string)<br/>  }))</pre> | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_aws_ecs_service"></a> [aws\_ecs\_service](#output\_aws\_ecs\_service) | The service for the given inputs. |
| <a name="output_aws_ecs_task_definition"></a> [aws\_ecs\_task\_definition](#output\_aws\_ecs\_task\_definition) | The task definition for the given inputs. |
<!-- END_TF_DOCS -->