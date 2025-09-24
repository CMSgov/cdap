variable "platform" {
  description = "Object that describes standardized platform values."
  type = any
}

variable "cluster_name_override" {
  description = "Name of the ecs cluster."
  type        = string
  default     = null
}
