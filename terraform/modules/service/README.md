# CDAP ECS Cluster Module

## Usage
A demo example is available in services/tftesting/ecs-stack.

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
| <a name="input_platform"></a> [platform](#input\_platform) | Object representing the CDAP plaform module. | <pre>object({<br/>    app               = string<br/>    env               = string<br/>    kms_alias_primary = object({ target_key_arn = string })<br/>    primary_region    = object({ name = string })<br/>    private_subnets   = map(object({ id = string }))<br/>    service           = string<br/>    account_id        = string<br/>    vpc_id            = string<br/>  })</pre> | n/a | yes |
| <a name="input_task_role_arn"></a> [task\_role\_arn](#input\_task\_role\_arn) | Distinct from execution role. ARN of the role that allows the application code in tasks to make calls to AWS services. | `string` | n/a | yes |
| <a name="input_alb_health_check"></a> [alb\_health\_check](#input\_alb\_health\_check) | Health check configuration for the ALB target group.<br/><br/>path                - HTTP path to probe (default: /health)<br/>port                - Port to probe. Use "traffic-port" to match the target group port<br/>matcher             - HTTP response codes considered healthy (default: "200-299")<br/>interval            - Seconds between health checks (default: 30)<br/>timeout             - Seconds before a check times out (default: 5)<br/>healthy\_threshold   - Consecutive successes to mark healthy (default: 2)<br/>unhealthy\_threshold - Consecutive failures to mark unhealthy (default: 3) | <pre>object({<br/>    path                = optional(string, "/health")<br/>    port                = optional(string, "traffic-port")<br/>    protocol            = optional(string, "HTTP")<br/>    matcher             = optional(string, "200-299")<br/>    interval            = optional(number, 30)<br/>    timeout             = optional(number, 5)<br/>    healthy_threshold   = optional(number, 2)<br/>    unhealthy_threshold = optional(number, 3)<br/>  })</pre> | `{}` | no |
| <a name="input_alb_listener_arn"></a> [alb\_listener\_arn](#input\_alb\_listener\_arn) | ARN of the ALB HTTPS listener to attach a listener rule to.<br/>When set, the module creates an aws\_lb\_target\_group and aws\_lb\_listener\_rule<br/>and wires the ECS service to the ALB.<br/>When null, no ALB integration is created. | `string` | `null` | no |
| <a name="input_alb_path_patterns"></a> [alb\_path\_patterns](#input\_alb\_path\_patterns) | Path pattern conditions for the ALB listener rule. Required when alb\_listener\_arn is set. | `list(string)` | `null` | no |
| <a name="input_alb_port_name"></a> [alb\_port\_name](#input\_alb\_port\_name) | Name of the port mapping to route ALB traffic to. Must match a name in var.port\_mappings. Required when alb\_listener\_arn is set. | `string` | `null` | no |
| <a name="input_alb_priority"></a> [alb\_priority](#input\_alb\_priority) | Listener rule priority (1–50000). Required when alb\_listener\_arn is set. | `number` | `null` | no |
| <a name="input_container_environment"></a> [container\_environment](#input\_container\_environment) | The environment variables to pass to the container | <pre>list(object({<br/>    name  = string<br/>    value = string<br/>  }))</pre> | `null` | no |
| <a name="input_container_secrets"></a> [container\_secrets](#input\_container\_secrets) | The secrets to pass to the container. For more information, see [Specifying Sensitive Data](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/specifying-sensitive-data.html) in the Amazon Elastic Container Service Developer Guide | <pre>list(object({<br/>    name      = string<br/>    valueFrom = string<br/>  }))</pre> | `null` | no |
| <a name="input_cpu_architecture"></a> [cpu\_architecture](#input\_cpu\_architecture) | The cpu architecture needed. | `string` | `"ARM64"` | no |
| <a name="input_deployment_circuit_breaker"></a> [deployment\_circuit\_breaker](#input\_deployment\_circuit\_breaker) | Deployment circuit breaker configuration. Stops a failing deployment. Set rollback = true to automatically revert to the previous task definition on failure. | <pre>object({<br/>    enable   = optional(bool, true)<br/>    rollback = optional(bool, false)<br/>  })</pre> | `{}` | no |
| <a name="input_deployment_maximum_percent"></a> [deployment\_maximum\_percent](#input\_deployment\_maximum\_percent) | Upper limit (as a percentage of desired\_count) of the number of running tasks<br/>that can exist during a deployment.<br/>Default is 200 — allows doubling the task count during a rolling deploy. | `number` | `200` | no |
| <a name="input_deployment_minimum_healthy_percent"></a> [deployment\_minimum\_healthy\_percent](#input\_deployment\_minimum\_healthy\_percent) | Lower limit (as a percentage of desired\_count) of the number of running tasks<br/>that must remain healthy during a deployment.<br/>Default is 100 — no tasks are taken down before new ones are healthy. | `number` | `100` | no |
| <a name="input_desired_count"></a> [desired\_count](#input\_desired\_count) | Number of instances of the task definition to place and keep running. | `number` | `1` | no |
| <a name="input_enable_ecs_service_connect"></a> [enable\_ecs\_service\_connect](#input\_enable\_ecs\_service\_connect) | Enables ECS Service Connect so other services in the namespace can reach this one. | `bool` | `false` | no |
| <a name="input_enable_execute_command"></a> [enable\_execute\_command](#input\_enable\_execute\_command) | Used only for testing. Requires task role to have ssm Permissions for ECS Exec. | `bool` | `false` | no |
| <a name="input_execution_role_arn"></a> [execution\_role\_arn](#input\_execution\_role\_arn) | Deprecated. Do not set. ARN of the role that grants Fargate agents permission to make AWS API calls to pull images for containers, get SSM params in the task definition, etc. Defaults to creation of a new role. | `string` | `null` | no |
| <a name="input_force_new_deployment"></a> [force\_new\_deployment](#input\_force\_new\_deployment) | When *changed* to `true`, trigger a new deployment of the ECS Service even when a deployment wouldn't otherwise be triggered by other changes. **Note**: This has no effect when the value is `false`, changed to `false`, or set to `true` between consecutive applies. | `bool` | `false` | no |
| <a name="input_health_check"></a> [health\_check](#input\_health\_check) | Health check that monitors the service. | <pre>object({<br/>    command     = list(string),<br/>    interval    = optional(number),<br/>    retries     = optional(number),<br/>    startPeriod = optional(number),<br/>    timeout     = optional(number)<br/>  })</pre> | `null` | no |
| <a name="input_health_check_grace_period_seconds"></a> [health\_check\_grace\_period\_seconds](#input\_health\_check\_grace\_period\_seconds) | Seconds to ignore failing load balancer health checks on newly instantiated tasks to prevent premature shutdown, up to 2147483647. Only valid for services configured to use load balancers. | `number` | `null` | no |
| <a name="input_ignore_desired_count_changes"></a> [ignore\_desired\_count\_changes](#input\_ignore\_desired\_count\_changes) | When true, Terraform will not revert desired\_count to the configured value on apply.<br/>Enable this when using Application Auto Scaling to manage task count at runtime. | `bool` | `false` | no |
| <a name="input_load_balancers"></a> [load\_balancers](#input\_load\_balancers) | DEPRECATED. Use alb\_listener\_arn and related variables. container\_name is optional — defaults to the module's resolved service name. | <pre>list(object({<br/>    target_group_arn = string<br/>    container_name   = optional(string)<br/>    container_port   = number<br/>  }))</pre> | `null` | no |
| <a name="input_log_retention_days"></a> [log\_retention\_days](#input\_log\_retention\_days) | Number of days to retain ECS task logs in CloudWatch. Required for production is minimum 180. | `number` | `180` | no |
| <a name="input_mount_points"></a> [mount\_points](#input\_mount\_points) | The mount points for data volumes in your container | <pre>list(object({<br/>    containerPath = optional(string)<br/>    readOnly      = optional(bool)<br/>    sourceVolume  = optional(string)<br/>  }))</pre> | `null` | no |
| <a name="input_port_mappings"></a> [port\_mappings](#input\_port\_mappings) | The list of port mappings for the container. Port mappings allow containers to access ports on the host container instance to send or receive traffic. For task definitions that use the awsvpc network mode, only specify the containerPort. The hostPort can be left blank or it must be the same value as the containerPort | <pre>list(object({<br/>    appProtocol        = optional(string)<br/>    containerPort      = optional(number)<br/>    containerPortRange = optional(string)<br/>    hostPort           = optional(number)<br/>    name               = optional(string)<br/>    protocol           = optional(string)<br/>  }))</pre> | `null` | no |
| <a name="input_security_groups"></a> [security\_groups](#input\_security\_groups) | List of security groups to associate with the service. | `list(string)` | `[]` | no |
| <a name="input_service_connect_dns_name"></a> [service\_connect\_dns\_name](#input\_service\_connect\_dns\_name) | Fully-qualified DNS name for the Service Connect client alias.<br/>Must satisfy the Name Constraints of the Private CA (e.g. "myservice.cmscloud.local").<br/>Defaults to the bare service name if not set — only override when using TLS with a constrained PCA. | `string` | `null` | no |
| <a name="input_service_connect_namespace"></a> [service\_connect\_namespace](#input\_service\_connect\_namespace) | Cloud Map HTTP namespace for ECS Service Connect.<br/>Pass the aws\_service\_discovery\_http\_namespace resource directly:<br/>  service\_connect\_namespace = aws\_service\_discovery\_http\_namespace.this<br/>The module uses .arn for the ECS service and .name for IAM condition scoping. | <pre>object({<br/>    arn  = string<br/>    name = string<br/>  })</pre> | `null` | no |
| <a name="input_service_connect_port"></a> [service\_connect\_port](#input\_service\_connect\_port) | Defaults to the first containerPort in port\_mappings. Override this for port remapping (e.g. expose on :80 while container listens on :8080). | `number` | `null` | no |
| <a name="input_service_connect_port_name"></a> [service\_connect\_port\_name](#input\_service\_connect\_port\_name) | Name of the port mapping to use for Service Connect. Defaults to the first named port in port\_mappings. | `string` | `null` | no |
| <a name="input_service_name_override"></a> [service\_name\_override](#input\_service\_name\_override) | Desired service name for the service tag on the aws ecs service.  Defaults to var.platform.app-var.platform.env-var.platform.service. | `string` | `null` | no |
| <a name="input_subnets"></a> [subnets](#input\_subnets) | Optional list of subnets associated with the service. Defaults to private subnets as specified by the platform module. | `list(string)` | `null` | no |
| <a name="input_volumes"></a> [volumes](#input\_volumes) | Configuration block for volumes that containers in your task may use | <pre>list(object({<br/>    configure_at_launch = optional(bool)<br/>    efs_volume_configuration = optional(object({<br/>      authorization_config = optional(object({<br/>        access_point_id = optional(string)<br/>        iam             = optional(string)<br/>      }))<br/>      file_system_id     = string<br/>      root_directory     = optional(string)<br/>      transit_encryption = optional(string) # deprecated: accepted but ignored, always ENABLED<br/>    }))<br/>    host_path = optional(string)<br/>    name      = string<br/>  }))</pre> | `null` | no |

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
| [aws_cloudwatch_log_group.app](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_ecs_service.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_service) | resource |
| [aws_ecs_task_definition.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_task_definition) | resource |
| [aws_iam_policy.service_connect](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.execution](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.service_connect](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.execution](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy_attachment.service_connect](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_lb_listener_rule.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener_rule) | resource |
| [aws_lb_target_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group) | resource |
| [aws_security_group.task](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_vpc_security_group_egress_rule.https](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_iam_policy_document.execution](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.service_connect](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_ram_resource_share.pace_ca](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ram_resource_share) | data source |
| [aws_ssm_parameter.datadog_api_key](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |
| [aws_ssm_parameter.secrets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |

<!--WARNING: GENERATED CONTENT with terraform-docs, e.g.
     'terraform-docs --config "$(git rev-parse --show-toplevel)/.terraform-docs.yml" .'
     Manually updating sections between TF_DOCS tags may be overwritten.
     See https://terraform-docs.io/user-guide/configuration/ for more information.
-->
## Outputs

| Name | Description |
|------|-------------|
| <a name="output_debug_sc_discovery_name"></a> [debug\_sc\_discovery\_name](#output\_debug\_sc\_discovery\_name) | n/a |
| <a name="output_debug_sc_dns_name"></a> [debug\_sc\_dns\_name](#output\_debug\_sc\_dns\_name) | n/a |
| <a name="output_debug_sc_namespace"></a> [debug\_sc\_namespace](#output\_debug\_sc\_namespace) | n/a |
| <a name="output_ecs_service_id"></a> [ecs\_service\_id](#output\_ecs\_service\_id) | ID of the ECS service. |
| <a name="output_ecs_service_name"></a> [ecs\_service\_name](#output\_ecs\_service\_name) | Full name of the ECS service. |
| <a name="output_listener_rule_arn"></a> [listener\_rule\_arn](#output\_listener\_rule\_arn) | ARN of the ALB listener rule (if ALB integration is enabled). |
| <a name="output_service"></a> [service](#output\_service) | The ECS service resource. |
| <a name="output_service_connect_role_arn"></a> [service\_connect\_role\_arn](#output\_service\_connect\_role\_arn) | ARN of the Service Connect IAM role (if Service Connect is enabled). |
| <a name="output_target_group_arn"></a> [target\_group\_arn](#output\_target\_group\_arn) | ARN of the ALB target group (if ALB integration is enabled). |
| <a name="output_task_definition"></a> [task\_definition](#output\_task\_definition) | The ECS task definition resource. |
| <a name="output_task_security_group_id"></a> [task\_security\_group\_id](#output\_task\_security\_group\_id) | ID of the ECS task security group (module-managed or first caller-provided). |
<!-- END_TF_DOCS -->
