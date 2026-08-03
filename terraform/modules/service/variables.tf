variable "cluster_arn" {
  description = "The ecs cluster ARN hosting the service and task."
  type        = string
}

variable "image" {
  description = <<-EOT
    Optional image URI override. If not provided, the service module will
    use the image_tag SSM parameter written by the build pipeline.
    NOTE: Direct image injection via this variable may be removed in a
    future release. Migrate to the build-and-push-docker workflow.
  EOT
  type        = string
  default     = null
}

variable "image_tag_service_name_override" {
  type        = string
  default     = null
  description = <<-EOT
    Override the service name used to construct the image tag SSM path.
    Use when the ECR repo and image tag SSM parameter belong to a different
    service than platform.service — for example, in test stacks that share
    a common test image. The service referenced by image_tag must exist already.
    Defaults to local.service_name.
    Resolves to: /<app>/<env>/nonsensitive/<override>/image-tag
  EOT
}

variable "ecr_repository_url" {
  description = <<-EOT
    ECR repository URL. If not provided, will be constructed from
    platform and service variables using the standard naming convention:
    {account}.dkr.ecr.{region}.amazonaws.com/{app}-{env}-{service}
  EOT
  type        = string
  default     = null
}

#
# mTLS Sidecar
#

variable "enable_mtls_sidecar" {
  type        = bool
  default     = false
  description = <<-EOT
    Retrieves the mTLS proxy sidecar from CDAP ECR.
    This flag is required separately because the data source count must be
    determinable at plan time, before the cert ARN is known.
  EOT
}

variable "mtls_cert_arn" {
  type        = string
  default     = null
  description = <<-EOT
    ARN of the PCA-backed private certificate used by the mTLS sidecar.
    When provided, enables mtls sidecar.
  EOT
}

variable "mtls_domain" {
  description = "FQDN the mTLS cert is issued for. Used by the startup self-test for hostname verification."
  type        = string
  default     = null
}

variable "proxy_listen_port" {
  type        = number
  default     = 8443
  description = <<-EOT
    Port the mTLS proxy sidecar listens on.

    Traffic flow when enable_mtls_sidecar = true:
      ALB --> proxy container :proxy_listen_port (mTLS)
          --> app container   :first port in port_mappings (plain HTTP, localhost)

    The ALB target group is automatically pointed at this port.
    The caller does not need to set alb_port_name.
  EOT
}

variable "proxy_healthcheck_port" {
  description = "Port for the proxy health check server (plain HTTP, no mTLS)"
  type        = number
  default     = 8081
}

variable "proxy_sidecar_upstream_port" {
  type        = number
  default     = 8080
  description = "Port the primary app container listens on. The proxy forwards to this port on localhost."
}

variable "alb_security_group_id" {
  description = "Security group ID of the ALB. Required when enable_alb_integration and mtls_cert_arn are both set. Used to create security group rules allowing ALB traffic to reach the mTLS proxy."
  type        = string
  default     = null


  validation {
    condition = !(
      var.mtls_cert_arn != null &&
      var.enable_alb_integration &&
      var.alb_listener_arn != null &&
      var.alb_security_group_id == null
    )
    error_message = "alb_security_group_id is required when mtls_cert_arn and alb_listener_arn are both set."
  }
}

# -------------------------------------------------------
# ECS Service Connect (optional)
# -------------------------------------------------------
variable "enable_ecs_service_connect" {
  description = "Enables ECS Service Connect so other services in the namespace can reach this one."
  type        = bool
  default     = false
}

variable "service_connect_namespace_arn" {
  type        = string
  default     = null
  description = <<-EOT
    ARN of the Cloud Map HTTP namespace to use for ECS Service Connect.
    When null, Service Connect will not be configured for this service.
  EOT
}

variable "service_connect_port" {
  type        = number
  default     = null
  description = "Optional. Defaults to the first containerPort in port_mappings. Override this for port remapping (e.g. expose on :80 while container listens on :8080)."
}

variable "service_connect_port_name" {
  type        = string
  default     = null
  description = "Optional. Defaults to the first named port in port_mappings. Name of the port mapping to use for Service Connect."
}

variable "service_connect_client_port" {
  type        = number
  default     = null
  description = <<-EOT
    Override the port clients use to call this service via Service Connect.
    Defaults to the containerPort of the named port mapping.
    Use this for port remapping (e.g. container listens on 8080, clients call on 80 for easy calls by name without port).
  EOT
}

variable "deployment_circuit_breaker" {
  type = object({
    enable   = optional(bool, true)
    rollback = optional(bool, false)
  })
  default     = {}
  description = "Deployment circuit breaker configuration. Stops a failing deployment. Set rollback = true to automatically revert to the previous task definition on failure."
}

variable "enable_execute_command" {
  type        = bool
  default     = false
  description = "Used only for testing. Requires task role to have ssm Permissions for ECS Exec."
}

variable "command" {
  description = "Only for testing. Setting this will trigger a SecurityHub alert. Overrides the default container command."
  type        = list(string)
  default     = null
}

# -------------------------------------------------------
# ECS Task (optional)
# -------------------------------------------------------

variable "container_environment" {
  description = "The environment variables to pass to the container"
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}

variable "container_secrets" {
  description = "The secrets to pass to the container. For more information, see [Specifying Sensitive Data](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/specifying-sensitive-data.html) in the Amazon Elastic Container Service Developer Guide"
  type = list(object({
    name      = string
    valueFrom = string
  }))
  default = []
}

variable "cpu" {
  description = "Number of cpu units used by the task."
  type        = number
}

variable "health_check_grace_period_seconds" {
  default     = null
  description = "Seconds to ignore failing load balancer health checks on newly instantiated tasks to prevent premature shutdown, up to 2147483647. Only valid for services configured to use load balancers."
  type        = number
}

variable "deployment_minimum_healthy_percent" {
  type        = number
  default     = 100
  description = <<-EOT
    Lower limit (as a percentage of desired_count) of the number of running tasks
    that must remain healthy during a deployment.
    Default is 100 — no tasks are taken down before new ones are healthy.
  EOT
}

variable "deployment_maximum_percent" {
  type        = number
  default     = 200
  description = <<-EOT
    Upper limit (as a percentage of desired_count) of the number of running tasks
    that can exist during a deployment.
    Default is 200 — allows doubling the task count during a rolling deploy.
  EOT
}

variable "desired_count" {
  description = "Number of instances of the task definition to place and keep running."
  type        = number
  default     = 1
}

variable "execution_role_arn" {
  description = "Deprecated. Do not set. ARN of the role that grants Fargate agents permission to make AWS API calls to pull images for containers, get SSM params in the task definition, etc. Defaults to creation of a new role."
  type        = string
  default     = null
}

variable "force_new_deployment" {
  description = "When *changed* to `true`, trigger a new deployment of the ECS Service even when a deployment wouldn't otherwise be triggered by other changes. **Note**: This has no effect when the value is `false`, changed to `false`, or set to `true` between consecutive applies."
  type        = bool
  default     = false
}

variable "cpu_architecture" {
  description = "The cpu architecture needed."
  type        = string
  default     = "ARM64"
}

variable "load_balancers" {
  description = "DEPRECATED. Use alb_listener_arn and related variables. container_name is optional — defaults to the module's resolved service name."
  type = list(object({
    target_group_arn = string
    container_name   = optional(string)
    container_port   = number
  }))
  default = null
}


#--------------------
# ALB Connection
#--------------------

variable "enable_alb_integration" {
  type        = bool
  default     = false
  description = <<-EOT
    Enable ALB integration. Must be set to true when alb_listener_arn is provided.
    Required as a separate flag because count on data sources and resources
    must be determinable at plan time, before the listener ARN is known.
  EOT
}

variable "alb_listener_arn" {
  type        = string
  default     = null
  description = <<-EOT
    ARN of the ALB HTTPS listener to attach a listener rule to.
    When set, the module creates an aws_lb_target_group and aws_lb_listener_rule
    and wires the ECS service to the ALB.
    When null, no ALB integration is created.
  EOT

  validation {
    condition     = !var.enable_alb_integration || var.alb_listener_arn != null
    error_message = "alb_listener_arn is required when enable_alb_integration = true."
  }
}

variable "alb_port_name" {
  type        = string
  default     = null
  description = "Name of the port mapping to route ALB traffic to. Must match a name in var.port_mappings. Required when alb_listener_arn is set."
}

variable "alb_health_check" {
  description = <<-EOT
    Health check configuration for the ALB target group.

    path                - HTTP path to probe (default: /health)
    port                - Port to probe. Use "traffic-port" to match the target group port
    matcher             - HTTP response codes considered healthy (default: "200-299")
    interval            - Seconds between health checks (default: 30)
    timeout             - Seconds before a check times out (default: 5)
    healthy_threshold   - Consecutive successes to mark healthy (default: 2)
    unhealthy_threshold - Consecutive failures to mark unhealthy (default: 3)
  EOT
  type = object({
    path                = optional(string, "/health")
    port                = optional(string, "traffic-port")
    protocol            = optional(string, null)
    matcher             = optional(string, "200-299")
    interval            = optional(number, 30)
    timeout             = optional(number, 5)
    healthy_threshold   = optional(number, 2)
    unhealthy_threshold = optional(number, 3)
  })
  default = {}
}

variable "alb_priority" {
  type    = number
  default = null

  validation {
    condition     = var.alb_priority == null || (var.alb_priority >= 1 && var.alb_priority <= 50000)
    error_message = "alb_priority must be between 1 and 50000."
  }

  description = "Listener rule priority (1–50000). Required when alb_listener_arn is set."
}

variable "alb_path_patterns" {
  type        = list(string)
  default     = ["/*"]
  description = "Path pattern conditions for the ALB listener rule. Required when alb_listener_arn is set."
}

variable "alb_target_group_protocol" {
  type        = string
  default     = "HTTP"
  description = "Protocol for the ALB target group. Use HTTPS if the container expects TLS traffic."
}

# reference:  https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task_definition_parameters.html#task_size
variable "memory" {
  description = "Amount (in MiB) of memory used by the task."
  type        = number
}

variable "readonly_root_filesystem" {
  description = "Whether to set the container root filesystem as read-only. ONLY set to false for containers that require write access (e.g., Datadog Private Location worker)."
  type        = bool
  default     = true
}

variable "mount_points" {
  description = "The mount points for data volumes in your container"
  type = list(object({
    containerPath = optional(string)
    readOnly      = optional(bool)
    sourceVolume  = optional(string)
  }))
  default = null
}

variable "platform" {
  description = "Object representing the CDAP plaform module."
  type = object({
    app                = string
    env                = string
    kms_alias_primary  = object({ target_key_arn = string })
    primary_region     = object({ name = string })
    private_subnets    = map(object({ id = string }))
    service            = string
    account_id         = string
    vpc_id             = string
    account_env_suffix = string
  })
}

variable "port_mappings" {
  description = "The list of port mappings for the container. Port mappings allow containers to access ports on the host container instance to send or receive traffic. For task definitions that use the awsvpc network mode, only specify the containerPort."
  type = list(object({
    appProtocol        = optional(string)
    containerPort      = optional(number)
    containerPortRange = optional(string)
    hostPort           = optional(number)
    name               = optional(string)
    protocol           = optional(string)
  }))
  default = null

  validation {
    condition = (
      !var.enable_mtls_sidecar ||
      var.port_mappings != null && length([
        for pm in coalesce(var.port_mappings, []) : pm
        if pm.name != "proxy" && pm.containerPort != null
      ]) > 0
    )
    error_message = "port_mappings must contain at least one non-proxy named port when enable_mtls_sidecar = true."
  }
}

variable "health_check" {
  description = "Health check that monitors the service."
  type = object({
    command     = list(string),
    interval    = optional(number),
    retries     = optional(number),
    startPeriod = optional(number),
    timeout     = optional(number)
  })
  default = null
}

variable "security_groups" {
  description = <<-EOT
    For most use cases, leave this empty. List of additional security group IDs to attach to the ECS task alongside the
    module-managed task security group.

    By default, the module creates and manages its own security group for the ECS task,
    with a scoped HTTPS egress rule. Ingress rules and any additional egress rules
    (e.g., service-to-service via Service Connect) should be managed in the caller
    using aws_vpc_security_group_ingress_rule / aws_vpc_security_group_egress_rule
    referencing module.service.task_security_group_id.
  EOT
  type        = list(string)
  default     = []
}

variable "service_name_override" {
  description = "Desired service name for the service tag on the aws ecs service.  Defaults to var.platform.app-var.platform.env-var.platform.service."
  type        = string
  default     = null
}

variable "subnets" {
  description = "Optional list of subnets associated with the service. Defaults to private subnets as specified by the platform module."
  type        = list(string)
  default     = null
}

variable "volumes" {
  description = "Configuration block for volumes that containers in your task may use"
  type = list(object({
    configure_at_launch = optional(bool)
    efs_volume_configuration = optional(object({
      authorization_config = optional(object({
        access_point_id = optional(string)
        iam             = optional(string)
      }))
      file_system_id     = string
      root_directory     = optional(string)
      transit_encryption = optional(string) # deprecated: accepted but ignored, always ENABLED
    }))
    host_path = optional(string)
    name      = string
  }))
  default = null
}

variable "log_retention_days" {
  type        = number
  default     = 180
  description = "Number of days to retain ECS task logs in CloudWatch. Required for production is minimum 180."

  validation {
    condition = contains(
      [0, 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731,
      1096, 1827, 2192, 2557, 2922, 3288, 3653],
      var.log_retention_days
    )
    error_message = "log_retention_days must be a value supported by CloudWatch Logs (e.g. 30, 90, 180, 365, 731). See: https://docs.aws.amazon.com/AmazonCloudWatchLogs/latest/APIReference/API_PutRetentionPolicy.html"
  }
}

## IAM
variable "additional_task_role_policies" {
  type        = map(string)
  default     = {}
  description = <<-EOT
    List of IAM managed policy ARNs to attach to the module-managed task role.
    Use this to grant the running container access to AWS resources
    (e.g., S3 buckets, DynamoDB tables, SQS queues) without modifying the module.
    Has no effect when task_role_arn is set (external role).
  EOT
}

## Monitoring
variable "enable_datadog_agent" {
  description = "Whether to include the Datadog agent sidecar container. Disable for batch/job tasks, tasks with tight resource limits, or tasks without Datadog network access."
  type        = bool
  default     = true
}

variable "enable_datadog_synthetics_ingress" {
  description = "Whether to include the security group ingress rule allowing traffic from the CDAP Datadog private location synthetic test runner."
  type        = bool
  default     = false
}

variable "dd_version" {
  description = "Version of the application reported to Datadog APM"
  type        = string
  default     = "1.0.0"
}
