# CDAP ECS Cluster Module
## Design Decisions

- **ACM certificates are not created here.** Use the `acm_certificate`
  module and pass ARNs explicitly. See architectural decision:
  *Explicit `acm_certificate` Module Instantiation*.
- **mTLS passphrase is ephemeral.** The proxy sidecar generates a
  one-time in-memory passphrase at startup, exports the cert from ACM,
  decrypts the private key to tmpfs, and discards the passphrase.
  No passphrase is stored in SSM or Terraform state.
- **ALB always targets the proxy when mTLS is enabled.** The proxy
  container receives ALB traffic on `proxy_listen_port` and forwards
  plain HTTP to the app container on localhost.
- **Image tag is managed via SSM.** The build workflow writes the image
  tag to SSM after a successful push. Terraform never overwrites it.


## Usage
A demo example is available in `services/611-tftesting-service`. 
A demo with use of ALB and ACM is in `services/612-tftesting-ecs-stack-internal` and `services/612-tftesting-ecs-stack-public`

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
| <a name="input_memory"></a> [memory](#input\_memory) | Amount (in MiB) of memory used by the task. | `number` | n/a | yes |
| <a name="input_platform"></a> [platform](#input\_platform) | Object representing the CDAP plaform module. | <pre>object({<br/>    app                = string<br/>    env                = string<br/>    kms_alias_primary  = object({ target_key_arn = string })<br/>    primary_region     = object({ name = string })<br/>    private_subnets    = map(object({ id = string }))<br/>    service            = string<br/>    account_id         = string<br/>    vpc_id             = string<br/>    account_env_suffix = string<br/>  })</pre> | n/a | yes |
| <a name="input_additional_task_role_policies"></a> [additional\_task\_role\_policies](#input\_additional\_task\_role\_policies) | List of IAM managed policy ARNs to attach to the module-managed task role.<br/>Use this to grant the running container access to AWS resources<br/>(e.g., S3 buckets, DynamoDB tables, SQS queues) without modifying the module.<br/>Has no effect when task\_role\_arn is set (external role). | `map(string)` | `{}` | no |
| <a name="input_alb_health_check"></a> [alb\_health\_check](#input\_alb\_health\_check) | Health check configuration for the ALB target group.<br/><br/>path                - HTTP path to probe (default: /health)<br/>port                - Port to probe. Use "traffic-port" to match the target group port<br/>matcher             - HTTP response codes considered healthy (default: "200-299")<br/>interval            - Seconds between health checks (default: 30)<br/>timeout             - Seconds before a check times out (default: 5)<br/>healthy\_threshold   - Consecutive successes to mark healthy (default: 2)<br/>unhealthy\_threshold - Consecutive failures to mark unhealthy (default: 3) | <pre>object({<br/>    path                = optional(string, "/health")<br/>    port                = optional(string, "traffic-port")<br/>    protocol            = optional(string, null)<br/>    matcher             = optional(string, "200-299")<br/>    interval            = optional(number, 30)<br/>    timeout             = optional(number, 5)<br/>    healthy_threshold   = optional(number, 2)<br/>    unhealthy_threshold = optional(number, 3)<br/>  })</pre> | `{}` | no |
| <a name="input_alb_listener_arn"></a> [alb\_listener\_arn](#input\_alb\_listener\_arn) | ARN of the ALB HTTPS listener to attach a listener rule to.<br/>When set, the module creates an aws\_lb\_target\_group and aws\_lb\_listener\_rule<br/>and wires the ECS service to the ALB.<br/>When null, no ALB integration is created. | `string` | `null` | no |
| <a name="input_alb_path_patterns"></a> [alb\_path\_patterns](#input\_alb\_path\_patterns) | Path pattern conditions for the ALB listener rule. Required when alb\_listener\_arn is set. | `list(string)` | <pre>[<br/>  "/*"<br/>]</pre> | no |
| <a name="input_alb_port_name"></a> [alb\_port\_name](#input\_alb\_port\_name) | Name of the port mapping to route ALB traffic to. Must match a name in var.port\_mappings. Required when alb\_listener\_arn is set. | `string` | `null` | no |
| <a name="input_alb_priority"></a> [alb\_priority](#input\_alb\_priority) | Listener rule priority (1–50000). Required when alb\_listener\_arn is set. | `number` | `null` | no |
| <a name="input_alb_security_group_id"></a> [alb\_security\_group\_id](#input\_alb\_security\_group\_id) | Security group ID of the ALB. Required when enable\_alb\_integration and mtls\_cert\_arn are both set. Used to create security group rules allowing ALB traffic to reach the mTLS proxy. | `string` | `null` | no |
| <a name="input_alb_target_group_protocol"></a> [alb\_target\_group\_protocol](#input\_alb\_target\_group\_protocol) | Protocol for the ALB target group. Use HTTPS if the container expects TLS traffic. | `string` | `"HTTP"` | no |
| <a name="input_command"></a> [command](#input\_command) | Only for testing. Setting this will trigger a SecurityHub alert. Overrides the default container command. | `list(string)` | `null` | no |
| <a name="input_container_environment"></a> [container\_environment](#input\_container\_environment) | The environment variables to pass to the container | <pre>list(object({<br/>    name  = string<br/>    value = string<br/>  }))</pre> | `[]` | no |
| <a name="input_container_secrets"></a> [container\_secrets](#input\_container\_secrets) | The secrets to pass to the container. For more information, see [Specifying Sensitive Data](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/specifying-sensitive-data.html) in the Amazon Elastic Container Service Developer Guide | <pre>list(object({<br/>    name      = string<br/>    valueFrom = string<br/>  }))</pre> | `[]` | no |
| <a name="input_cpu_architecture"></a> [cpu\_architecture](#input\_cpu\_architecture) | The cpu architecture needed. | `string` | `"ARM64"` | no |
| <a name="input_dd_version"></a> [dd\_version](#input\_dd\_version) | Version of the application reported to Datadog APM | `string` | `"1.0.0"` | no |
| <a name="input_deployment_circuit_breaker"></a> [deployment\_circuit\_breaker](#input\_deployment\_circuit\_breaker) | Deployment circuit breaker configuration. Stops a failing deployment. Set rollback = true to automatically revert to the previous task definition on failure. | <pre>object({<br/>    enable   = optional(bool, true)<br/>    rollback = optional(bool, false)<br/>  })</pre> | `{}` | no |
| <a name="input_deployment_maximum_percent"></a> [deployment\_maximum\_percent](#input\_deployment\_maximum\_percent) | Upper limit (as a percentage of desired\_count) of the number of running tasks<br/>that can exist during a deployment.<br/>Default is 200 — allows doubling the task count during a rolling deploy. | `number` | `200` | no |
| <a name="input_deployment_minimum_healthy_percent"></a> [deployment\_minimum\_healthy\_percent](#input\_deployment\_minimum\_healthy\_percent) | Lower limit (as a percentage of desired\_count) of the number of running tasks<br/>that must remain healthy during a deployment.<br/>Default is 100 — no tasks are taken down before new ones are healthy. | `number` | `100` | no |
| <a name="input_desired_count"></a> [desired\_count](#input\_desired\_count) | Number of instances of the task definition to place and keep running. | `number` | `1` | no |
| <a name="input_ecr_repository_url"></a> [ecr\_repository\_url](#input\_ecr\_repository\_url) | ECR repository URL. If not provided, will be constructed from<br/>platform and service variables using the standard naming convention:<br/>{account}.dkr.ecr.{region}.amazonaws.com/{app}-{env}-{service} | `string` | `null` | no |
| <a name="input_enable_alb_integration"></a> [enable\_alb\_integration](#input\_enable\_alb\_integration) | Enable ALB integration. Must be set to true when alb\_listener\_arn is provided.<br/>Required as a separate flag because count on data sources and resources<br/>must be determinable at plan time, before the listener ARN is known. | `bool` | `false` | no |
| <a name="input_enable_datadog_agent"></a> [enable\_datadog\_agent](#input\_enable\_datadog\_agent) | Whether to include the Datadog agent sidecar container. Disable for batch/job tasks, tasks with tight resource limits, or tasks without Datadog network access. | `bool` | `true` | no |
| <a name="input_enable_datadog_synthetics_ingress"></a> [enable\_datadog\_synthetics\_ingress](#input\_enable\_datadog\_synthetics\_ingress) | Whether to include the security group ingress rule allowing traffic from the CDAP Datadog private location synthetic test runner. | `bool` | `false` | no |
| <a name="input_enable_ecs_service_connect"></a> [enable\_ecs\_service\_connect](#input\_enable\_ecs\_service\_connect) | Enables ECS Service Connect so other services in the namespace can reach this one. | `bool` | `false` | no |
| <a name="input_enable_execute_command"></a> [enable\_execute\_command](#input\_enable\_execute\_command) | Used only for testing. Requires task role to have ssm Permissions for ECS Exec. | `bool` | `false` | no |
| <a name="input_enable_mtls_sidecar"></a> [enable\_mtls\_sidecar](#input\_enable\_mtls\_sidecar) | Retrieves the mTLS proxy sidecar from CDAP ECR.<br/>This flag is required separately because the data source count must be<br/>determinable at plan time, before the cert ARN is known. | `bool` | `false` | no |
| <a name="input_execution_role_arn"></a> [execution\_role\_arn](#input\_execution\_role\_arn) | Deprecated. Do not set. ARN of the role that grants Fargate agents permission to make AWS API calls to pull images for containers, get SSM params in the task definition, etc. Defaults to creation of a new role. | `string` | `null` | no |
| <a name="input_force_new_deployment"></a> [force\_new\_deployment](#input\_force\_new\_deployment) | When *changed* to `true`, trigger a new deployment of the ECS Service even when a deployment wouldn't otherwise be triggered by other changes. **Note**: This has no effect when the value is `false`, changed to `false`, or set to `true` between consecutive applies. | `bool` | `false` | no |
| <a name="input_health_check"></a> [health\_check](#input\_health\_check) | Health check that monitors the service. | <pre>object({<br/>    command     = list(string),<br/>    interval    = optional(number),<br/>    retries     = optional(number),<br/>    startPeriod = optional(number),<br/>    timeout     = optional(number)<br/>  })</pre> | `null` | no |
| <a name="input_health_check_grace_period_seconds"></a> [health\_check\_grace\_period\_seconds](#input\_health\_check\_grace\_period\_seconds) | Seconds to ignore failing load balancer health checks on newly instantiated tasks to prevent premature shutdown, up to 2147483647. Only valid for services configured to use load balancers. | `number` | `null` | no |
| <a name="input_image"></a> [image](#input\_image) | Optional image URI override. If not provided, the service module will<br/>use the image\_tag SSM parameter written by the build pipeline.<br/>NOTE: Direct image injection via this variable may be removed in a<br/>future release. Migrate to the build-and-push-docker workflow. | `string` | `null` | no |
| <a name="input_image_tag_service_name_override"></a> [image\_tag\_service\_name\_override](#input\_image\_tag\_service\_name\_override) | Override the service name used to construct the image tag SSM path.<br/>Use when the ECR repo and image tag SSM parameter belong to a different<br/>service than platform.service — for example, in test stacks that share<br/>a common test image. The service referenced by image\_tag must exist already.<br/>Defaults to local.service\_name.<br/>Resolves to: /<app>/<env>/nonsensitive/<override>/image-tag | `string` | `null` | no |
| <a name="input_load_balancers"></a> [load\_balancers](#input\_load\_balancers) | DEPRECATED. Use alb\_listener\_arn and related variables. container\_name is optional — defaults to the module's resolved service name. | <pre>list(object({<br/>    target_group_arn = string<br/>    container_name   = optional(string)<br/>    container_port   = number<br/>  }))</pre> | `null` | no |
| <a name="input_log_retention_days"></a> [log\_retention\_days](#input\_log\_retention\_days) | Number of days to retain ECS task logs in CloudWatch. Required for production is minimum 180. | `number` | `180` | no |
| <a name="input_mount_points"></a> [mount\_points](#input\_mount\_points) | The mount points for data volumes in your container | <pre>list(object({<br/>    containerPath = optional(string)<br/>    readOnly      = optional(bool)<br/>    sourceVolume  = optional(string)<br/>  }))</pre> | `null` | no |
| <a name="input_mtls_cert_arn"></a> [mtls\_cert\_arn](#input\_mtls\_cert\_arn) | ARN of the PCA-backed private certificate used by the mTLS sidecar.<br/>When provided, enables mtls sidecar. | `string` | `null` | no |
| <a name="input_mtls_domain"></a> [mtls\_domain](#input\_mtls\_domain) | FQDN the mTLS cert is issued for. Used by the startup self-test for hostname verification. | `string` | `null` | no |
| <a name="input_mtls_require_client_cert"></a> [mtls\_require\_client\_cert](#input\_mtls\_require\_client\_cert) | Not yet available. Whether to require client certificates on the mTLS proxy. Set to true only when client cert issuance is configured. | `bool` | `false` | no |
| <a name="input_port_mappings"></a> [port\_mappings](#input\_port\_mappings) | The list of port mappings for the container. Port mappings allow containers to access ports on the host container instance to send or receive traffic. For task definitions that use the awsvpc network mode, only specify the containerPort. | <pre>list(object({<br/>    appProtocol        = optional(string)<br/>    containerPort      = optional(number)<br/>    containerPortRange = optional(string)<br/>    hostPort           = optional(number)<br/>    name               = optional(string)<br/>    protocol           = optional(string)<br/>  }))</pre> | `null` | no |
| <a name="input_proxy_healthcheck_port"></a> [proxy\_healthcheck\_port](#input\_proxy\_healthcheck\_port) | Port for the proxy health check server (plain HTTP, no mTLS) | `number` | `8081` | no |
| <a name="input_proxy_listen_port"></a> [proxy\_listen\_port](#input\_proxy\_listen\_port) | Port the mTLS proxy sidecar listens on.<br/><br/>Traffic flow when enable\_mtls\_sidecar = true:<br/>  ALB --> proxy container :proxy\_listen\_port (mTLS)<br/>      --> app container   :first port in port\_mappings (plain HTTP, localhost)<br/><br/>The ALB target group is automatically pointed at this port.<br/>The caller does not need to set alb\_port\_name. | `number` | `8443` | no |
| <a name="input_proxy_sidecar_upstream_port"></a> [proxy\_sidecar\_upstream\_port](#input\_proxy\_sidecar\_upstream\_port) | Port the primary app container listens on. The proxy forwards to this port on localhost. | `number` | `8080` | no |
| <a name="input_readonly_root_filesystem"></a> [readonly\_root\_filesystem](#input\_readonly\_root\_filesystem) | Whether to set the container root filesystem as read-only. ONLY set to false for containers that require write access (e.g., Datadog Private Location worker). | `bool` | `true` | no |
| <a name="input_security_groups"></a> [security\_groups](#input\_security\_groups) | For most use cases, leave this empty. List of additional security group IDs to attach to the ECS task alongside the<br/>module-managed task security group.<br/><br/>By default, the module creates and manages its own security group for the ECS task,<br/>with a scoped HTTPS egress rule. Ingress rules and any additional egress rules<br/>(e.g., service-to-service via Service Connect) should be managed in the caller<br/>using aws\_vpc\_security\_group\_ingress\_rule / aws\_vpc\_security\_group\_egress\_rule<br/>referencing module.service.task\_security\_group\_id. | `list(string)` | `[]` | no |
| <a name="input_service_connect_client_port"></a> [service\_connect\_client\_port](#input\_service\_connect\_client\_port) | Override the port clients use to call this service via Service Connect.<br/>Defaults to the containerPort of the named port mapping.<br/>Use this for port remapping (e.g. container listens on 8080, clients call on 80 for easy calls by name without port). | `number` | `null` | no |
| <a name="input_service_connect_namespace_arn"></a> [service\_connect\_namespace\_arn](#input\_service\_connect\_namespace\_arn) | ARN of the Cloud Map HTTP namespace to use for ECS Service Connect.<br/>When null, Service Connect will not be configured for this service. | `string` | `null` | no |
| <a name="input_service_connect_port"></a> [service\_connect\_port](#input\_service\_connect\_port) | Optional. Defaults to the first containerPort in port\_mappings. Override this for port remapping (e.g. expose on :80 while container listens on :8080). | `number` | `null` | no |
| <a name="input_service_connect_port_name"></a> [service\_connect\_port\_name](#input\_service\_connect\_port\_name) | Optional. Defaults to the first named port in port\_mappings. Name of the port mapping to use for Service Connect. | `string` | `null` | no |
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
| [aws_cloudwatch_log_group.datadog](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_ecs_service.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_service) | resource |
| [aws_ecs_task_definition.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_task_definition) | resource |
| [aws_iam_policy.ecs_exec](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.service_connect](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.execution](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.service_connect](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.task](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.execution](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.task](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy_attachment.service_connect](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.task_additional](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_lb_listener_rule.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener_rule) | resource |
| [aws_lb_target_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group) | resource |
| [aws_security_group.task](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_ssm_parameter.image_tag](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_vpc_security_group_egress_rule.alb_to_task_health](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.alb_to_task_proxy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.https](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.alb_to_health](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.alb_to_proxy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.datadog_synthetics](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.datadog_to_app](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.datadog_to_health](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.datadog_to_proxy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_iam_policy_document.ecs_exec](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.execution](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.service_connect](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.task](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_ram_resource_share.pace_ca](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ram_resource_share) | data source |
| [aws_ssm_parameter.active_image_tag](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |
| [aws_ssm_parameter.datadog_api_key](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |
| [aws_ssm_parameter.datadog_private_location_sg](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |
| [aws_ssm_parameter.mtls_image_tag](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |
| [aws_ssm_parameter.secrets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |

<!--WARNING: GENERATED CONTENT with terraform-docs, e.g.
     'terraform-docs --config "$(git rev-parse --show-toplevel)/.terraform-docs.yml" .'
     Manually updating sections between TF_DOCS tags may be overwritten.
     See https://terraform-docs.io/user-guide/configuration/ for more information.
-->
## Outputs

| Name | Description |
|------|-------------|
| <a name="output_ecs_service_id"></a> [ecs\_service\_id](#output\_ecs\_service\_id) | ID of the ECS service. |
| <a name="output_ecs_service_name"></a> [ecs\_service\_name](#output\_ecs\_service\_name) | Full name of the ECS service. |
| <a name="output_full_name_override"></a> [full\_name\_override](#output\_full\_name\_override) | Full name of the ECS service. |
| <a name="output_listener_rule_arn"></a> [listener\_rule\_arn](#output\_listener\_rule\_arn) | ARN of the ALB listener rule (if ALB integration is enabled). |
| <a name="output_service"></a> [service](#output\_service) | The ECS service resource. |
| <a name="output_service_connect_endpoint"></a> [service\_connect\_endpoint](#output\_service\_connect\_endpoint) | Full Service Connect endpoint for this service (e.g. http://api:8080). Null if Service Connect is not enabled. |
| <a name="output_service_connect_name"></a> [service\_connect\_name](#output\_service\_connect\_name) | Short DNS name for this service within the Service Connect namespace. Other services call this service at http://<service\_connect\_name>:<service\_connect\_port>/. |
| <a name="output_service_connect_port"></a> [service\_connect\_port](#output\_service\_connect\_port) | Port clients should use when calling this service via Service Connect. |
| <a name="output_service_connect_role_arn"></a> [service\_connect\_role\_arn](#output\_service\_connect\_role\_arn) | ARN of the Service Connect IAM role (if Service Connect is enabled). |
| <a name="output_target_group_arn"></a> [target\_group\_arn](#output\_target\_group\_arn) | ARN of the ALB target group (if ALB integration is enabled). |
| <a name="output_task_definition"></a> [task\_definition](#output\_task\_definition) | The ECS task definition resource. |
| <a name="output_task_role_arn"></a> [task\_role\_arn](#output\_task\_role\_arn) | ARN of the ECS task role (module-managed or externally provided). |
| <a name="output_task_security_group_id"></a> [task\_security\_group\_id](#output\_task\_security\_group\_id) | ID of the ECS task security group (module-managed or first caller-provided). |
<!-- END_TF_DOCS -->
