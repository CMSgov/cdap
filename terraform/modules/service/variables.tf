variable "cluster" {
  description = "The ecs cluster hosting the service and task."
  type        = any
}

variable "container_definitions_filename" {
  description = "Valid container definitions provided as a single valid JSON document."
  type        = string
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
  description = "Enable to delete a service even if it wasn't scaled down to zero tasks. Default is false."
  type        = bool
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

variable "volumes" {
  description = "EBS volumes to create for the ecs task definition."
  type = list(string)
}
