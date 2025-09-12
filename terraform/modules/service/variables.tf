variable "cluster" {
  description = "The ecs cluster hosting the service and task."
  type        = any
}

variable "container_environment" {
  description = "The environment variables to pass to the container"
  type = list(object({
    name  = string
    value = string
  }))
  default = null
}

variable "container_secrets" {
  description = "The secrets to pass to the container. For more information, see [Specifying Sensitive Data](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/specifying-sensitive-data.html) in the Amazon Elastic Container Service Developer Guide"
  type = list(object({
    name      = string
    valueFrom = string
  }))
  default = null
}

variable "cpu" {
  description = "Number of cpu units used by the task."
  type        = number
}

variable "desired_count" {
  description = "Number of instances of the task definition to place and keep running."
  type        = number
  default     = 0
}

variable "family_name_override" {
  default     = null
  description = "The desired family name for the ECS task definition.  If null will default to: {var.platform.env}-{var.platform.app}-{var.platform.service}"
}

variable "force_new_deployment" {
  default     = false
  description = "When *changed* to `true`, trigger a new deployment of the ECS Service even when a deployment wouldn't otherwise be triggered by other changes. **Note**: This has no effect when the value is `false`, changed to `false`, or set to `true` between consecutive applies."
  type        = bool
}


variable "image" {
  description = "The image used to start a container. This string is passed directly to the Docker daemon. By default, images in the Docker Hub registry are available. Other repositories are specified with either `repository-url/image:tag` or `repository-url/image@digest`"
  type        = string
  default     = null
}

variable "load_balancers" {
  description = "Load balancer(s) for use by the AWS ECS service."
  type = list(object({
    target_group_arn = string
    container_name   = string
    container_port   = number
  }))
}

variable "memory" {
  description = "Amount (in MiB) of memory used by the task."
  type        = number
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


variable "network_configurations" {
  description = "Network configuration for the aws ecs service."
  type = list(object({
    subnets          = list(string)
    assign_public_ip = string
    security_groups  = list(string)
  }))
}

variable "platform" {
  description = "Object that describes standardized platform values."
  type        = any
}

variable "port_mappings" {
  description = "The list of port mappings for the container. Port mappings allow containers to access ports on the host container instance to send or receive traffic. For task definitions that use the awsvpc network mode, only specify the containerPort. The hostPort can be left blank or it must be the same value as the containerPort"
  type = list(object({
    appProtocol        = optional(string)
    containerPort      = optional(number)
    containerPortRange = optional(string)
    hostPort           = optional(number)
    name               = optional(string)
    protocol           = optional(string)
  }))
  default = null
}

variable "propagate_tags" {
  default     = "SERVICE"
  description = "Determines whether to propagate the tags from the task definition to the Amazon EBS volume."
  type        = string
  validation {
    condition     = contains(["SERVICE", "TASK_DEFINITION"], var.propagate_tags)
    error_message = "Invalid propagate_tags setting. Must be 'SERVICE' or 'TASK_DEFINITION'"
  }
}

variable "service_name_override" {
  default     = null
  description = "Desired service name for the service tag on the aws ecs service.  Defaults to platform.service."
  type        = string
}

variable "task_execution_role_arn" {
  default     = null
  description = "ARN of the task execution role that the Amazon ECS container agent and the Docker daemon can assume.  Defaults to creation of a new role."
  type        = string
}

variable "task_app_role_arn" {
  description = "ARN of IAM role that allows your Amazon ECS container task to make calls to other AWS services."
}

variable "volume" {
  description = "Configuration block for volumes that containers in your task may use"
  type = map(object({
    configure_at_launch = optional(bool)
    docker_volume_configuration = optional(object({
      autoprovision = optional(bool)
      driver        = optional(string)
      driver_opts   = optional(map(string))
      labels        = optional(map(string))
      scope         = optional(string)
    }))
    efs_volume_configuration = optional(object({
      authorization_config = optional(object({
        access_point_id = optional(string)
        iam             = optional(string)
      }))
      file_system_id          = string
      root_directory          = optional(string)
      transit_encryption      = optional(string)
      transit_encryption_port = optional(number)
    }))
    host_path = optional(string)
    name      = optional(string)
  }))
  default = null
}

################################################################################
# CloudWatch Log Group
################################################################################

variable "enable_cloudwatch_logging" {
  description = "Determines whether CloudWatch logging is configured for this container definition. Set to `false` to use other logging drivers"
  type        = bool
  default     = true
  nullable    = false
}

variable "create_cloudwatch_log_group" {
  description = "Determines whether a log group is created by this module. If not, AWS will automatically create one if logging is enabled"
  type        = bool
  default     = true
  nullable    = false
}

variable "cloudwatch_log_group_name" {
  description = "Custom name of CloudWatch log group for a service associated with the container definition"
  type        = string
  default     = null
}

variable "cloudwatch_log_group_use_name_prefix" {
  description = "Determines whether the log group name should be used as a prefix"
  type        = bool
  default     = false
  nullable    = false
}

variable "cloudwatch_log_group_class" {
  description = "Specified the log class of the log group. Possible values are: `STANDARD` or `INFREQUENT_ACCESS`"
  type        = string
  default     = null
}

variable "cloudwatch_log_group_retention_in_days" {
  description = "Number of days to retain log events. Set to `0` to keep logs indefinitely"
  type        = number
  default     = 14
  nullable    = false
}

variable "cloudwatch_log_group_kms_key_id" {
  description = "If a KMS Key ARN is set, this key will be used to encrypt the corresponding log group. Please be sure that the KMS Key has an appropriate key policy (https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/encrypt-log-data-kms.html)"
  type        = string
  default     = null
}
