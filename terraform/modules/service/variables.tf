variable "cluster_arn" {
  description = "The ecs cluster ARN hosting the service and task."
  type        = string
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

# reference:  https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task_definition_parameters.html#task_size
variable "memory" {
  description = "Amount (in MiB) of memory used by the task."
  type        = number
}

variable "desired_count" {
  description = "Number of instances of the task definition to place and keep running."
  type        = number
  default     = 1
}

variable "execution_role_arn" {
  description = "ARN of the task execution role that the Amazon ECS container agent and the Docker daemon can assume.  Defaults to creation of a new role."
  type        = string
  default     = null
}

variable "force_new_deployment" {
  description = "When *changed* to `true`, trigger a new deployment of the ECS Service even when a deployment wouldn't otherwise be triggered by other changes. **Note**: This has no effect when the value is `false`, changed to `false`, or set to `true` between consecutive applies."
  type        = bool
  default     = false
}

variable "image" {
  description = "The image used to start a container. This string is passed directly to the Docker daemon. By default, images in the Docker Hub registry are available. Other repositories are specified with either `repository-url/image:tag` or `repository-url/image@digest`"
  type        = string
}

variable "load_balancers" {
  description = "Load balancer(s) for use by the AWS ECS service."
  type = list(object({
    target_group_arn = string
    container_name   = string
    container_port   = number
  }))
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
    app               = string
    env               = string
    kms_alias_primary = object({ target_key_arn = string })
    primary_region    = object({ name = string })
    private_subnets   = map(string)
    service           = string
  })
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

variable "security_groups" {
  description = "List of security groups to associate with the service."
  type        = list(string)
  default     = []
}

variable "service_name_override" {
  description = "Desired service name for the service tag on the aws ecs service.  Defaults to var.platform.app-var.platform.env-var.platform.service."
  type        = string
  default     = null
}

variable "task_role_arn" {
  description = "ARN of IAM role that allows your Amazon ECS container task to make calls to other AWS services."
  type        = string
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
      file_system_id = string
      root_directory = optional(string)
    }))
    host_path = optional(string)
    name      = optional(string)
  }))
  default = null
}
