variable "env" {
  type        = string
  description = "The environment to target"
  default     = "prod"
}
variable "service_name" {
  description = "The name of the service (e.g., dpc or ab2d)"
  type        = string
  default = "ab2d"
}

