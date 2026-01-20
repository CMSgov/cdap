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
  source          = "github.com/CMSgov/cdap//terraform/modules/service?ref=<hash>"
  platform        = module.platform
  cluster_arn     = module.cluster.this.arn
  image           = local.api_image_uri
  cpu             = local.ecs_task_def_cpu_api
  memory          = local.ecs_task_def_memory_api
  desired_count   = local.api_desired_instances
  port_mappings   = [{ containerPort = local.container_port }]
  security_groups = [data.aws_security_group.api.id, aws_security_group.load_balancer.id]
  task_role_arn   = data.aws_iam_role.api.arn

  force_new_deployment = anytrue([var.force_api_deployment, var.api_service_image_tag != null])

  container_environment = [
    { name = "AB2D_BFD_INSIGHTS", value = local.bfd_insights },
    { name = "AB2D_DB_HOST", value = local.ab2d_db_host },
  ]
  container_secrets = [
    { name = "AB2D_DB_DATABASE", valueFrom = local.db_name_arn },
    { name = "AB2D_DB_PASSWORD", valueFrom = local.db_password_arn },
  ]
  load_balancers = [{
    target_group_arn = aws_lb_target_group.ab2d_api.arn
    container_name   = local.service
    container_port   = local.container_port
  }]
  mount_points = [
    {
      containerPath = local.ab2d_efs_mount,
      sourceVolume  = "efs",
    },
    {
      "containerPath" = "/var/log",
      "sourceVolume"  = "var_log",
    },
  ]
  volumes = [
    {
      name = "efs"
      efs_volume_configuration = {
        file_system_id     = data.aws_efs_file_system.this.id
        root_directory     = "/"
        transit_encryption = "ENABLED"
        authorization_config = {
          access_point_id = data.aws_efs_access_point.this.id
        }
      }
    },
    {
      name = "var_log"
    },
  ]
}
```

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
| <a name="input_cluster_arn"></a> [cluster\_arn](#input\_cluster\_arn) | The ecs cluster ARN hosting the service and task. | `string` | n/a | yes |
| <a name="input_cpu"></a> [cpu](#input\_cpu) | Number of cpu units used by the task. | `number` | n/a | yes |
| <a name="input_image"></a> [image](#input\_image) | The image used to start a container. This string is passed directly to the Docker daemon. By default, images in the Docker Hub registry are available. Other repositories are specified with either `repository-url/image:tag` or `repository-url/image@digest` | `string` | n/a | yes |
| <a name="input_memory"></a> [memory](#input\_memory) | Amount (in MiB) of memory used by the task. | `number` | n/a | yes |
| <a name="input_platform"></a> [platform](#input\_platform) | Object representing the CDAP plaform module. | <pre>object({<br/>    app               = string<br/>    env               = string<br/>    kms_alias_primary = object({ target_key_arn = string })<br/>    primary_region    = object({ name = string })<br/>    private_subnets   = map(object({ id = string }))<br/>    service           = string<br/>  })</pre> | n/a | yes |
| <a name="input_task_role_arn"></a> [task\_role\_arn](#input\_task\_role\_arn) | ARN of the role that allows the application code in tasks to make calls to AWS services. | `string` | n/a | yes |
| <a name="input_container_environment"></a> [container\_environment](#input\_container\_environment) | The environment variables to pass to the container | <pre>list(object({<br/>    name  = string<br/>    value = string<br/>  }))</pre> | `null` | no |
| <a name="input_container_secrets"></a> [container\_secrets](#input\_container\_secrets) | The secrets to pass to the container. For more information, see [Specifying Sensitive Data](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/specifying-sensitive-data.html) in the Amazon Elastic Container Service Developer Guide | <pre>list(object({<br/>    name      = string<br/>    valueFrom = string<br/>  }))</pre> | `null` | no |
| <a name="input_desired_count"></a> [desired\_count](#input\_desired\_count) | Number of instances of the task definition to place and keep running. | `number` | `1` | no |
| <a name="input_execution_role_arn"></a> [execution\_role\_arn](#input\_execution\_role\_arn) | ARN of the role that grants Fargate agents permission to make AWS API calls to pull images for containers, get SSM params in the task definition, etc. Defaults to creation of a new role. | `string` | `null` | no |
| <a name="input_force_new_deployment"></a> [force\_new\_deployment](#input\_force\_new\_deployment) | When *changed* to `true`, trigger a new deployment of the ECS Service even when a deployment wouldn't otherwise be triggered by other changes. **Note**: This has no effect when the value is `false`, changed to `false`, or set to `true` between consecutive applies. | `bool` | `false` | no |
| <a name="input_health_check"></a> [health\_check](#input\_health\_check) | Health check that monitors the service. | <pre>object({<br/>    command     = list(string),<br/>    interval    = optional(number),<br/>    retries     = optional(number),<br/>    startPeriod = optional(number),<br/>    timeout     = optional(number)<br/>  })</pre> | `null` | no |
| <a name="input_health_check_grace_period_seconds"></a> [health\_check\_grace\_period\_seconds](#input\_health\_check\_grace\_period\_seconds) | Seconds to ignore failing load balancer health checks on newly instantiated tasks to prevent premature shutdown, up to 2147483647. Only valid for services configured to use load balancers. | `number` | `null` | no |
| <a name="input_load_balancers"></a> [load\_balancers](#input\_load\_balancers) | Load balancer(s) for use by the AWS ECS service. | <pre>list(object({<br/>    target_group_arn = string<br/>    container_name   = string<br/>    container_port   = number<br/>  }))</pre> | `[]` | no |
| <a name="input_mount_points"></a> [mount\_points](#input\_mount\_points) | The mount points for data volumes in your container | <pre>list(object({<br/>    containerPath = optional(string)<br/>    readOnly      = optional(bool)<br/>    sourceVolume  = optional(string)<br/>  }))</pre> | `null` | no |
| <a name="input_port_mappings"></a> [port\_mappings](#input\_port\_mappings) | The list of port mappings for the container. Port mappings allow containers to access ports on the host container instance to send or receive traffic. For task definitions that use the awsvpc network mode, only specify the containerPort. The hostPort can be left blank or it must be the same value as the containerPort | <pre>list(object({<br/>    appProtocol        = optional(string)<br/>    containerPort      = optional(number)<br/>    containerPortRange = optional(string)<br/>    hostPort           = optional(number)<br/>    name               = optional(string)<br/>    protocol           = optional(string)<br/>  }))</pre> | `null` | no |
| <a name="input_security_groups"></a> [security\_groups](#input\_security\_groups) | List of security groups to associate with the service. | `list(string)` | `[]` | no |
| <a name="input_service_name_override"></a> [service\_name\_override](#input\_service\_name\_override) | Desired service name for the service tag on the aws ecs service.  Defaults to var.platform.app-var.platform.env-var.platform.service. | `string` | `null` | no |
| <a name="input_subnets"></a> [subnets](#input\_subnets) | Optional list of subnets associated with the service. | `list(string)` | `null` | no |
| <a name="input_volumes"></a> [volumes](#input\_volumes) | Configuration block for volumes that containers in your task may use | <pre>list(object({<br/>    configure_at_launch = optional(bool)<br/>    efs_volume_configuration = optional(object({<br/>      authorization_config = optional(object({<br/>        access_point_id = optional(string)<br/>        iam             = optional(string)<br/>      }))<br/>      file_system_id = string<br/>      root_directory = optional(string)<br/>    }))<br/>    host_path = optional(string)<br/>    name      = string<br/>  }))</pre> | `null` | no |

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
| [aws_ecs_service.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_service) | resource |
| [aws_ecs_task_definition.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_task_definition) | resource |
| [aws_iam_role.execution](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.execution](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_policy_document.execution](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |

<!--WARNING: GENERATED CONTENT with terraform-docs, e.g.
     'terraform-docs --config "$(git rev-parse --show-toplevel)/.terraform-docs.yml" .'
     Manually updating sections between TF_DOCS tags may be overwritten.
     See https://terraform-docs.io/user-guide/configuration/ for more information.
-->
## Outputs

| Name | Description |
|------|-------------|
| <a name="output_service"></a> [service](#output\_service) | The ecs service for the given inputs. |
| <a name="output_task_definition"></a> [task\_definition](#output\_task\_definition) | The ecs task definition for the given inputs. |
<!-- END_TF_DOCS -->
