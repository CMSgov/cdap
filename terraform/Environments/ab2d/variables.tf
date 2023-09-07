variable "env" {
  type        = string
  description = "The environment to target"
  default     = "prod"
}
variable "environment" {
  description = "The name of the service (e.g., dpc or ab2d)"
  type        = string
  default = "ab2d"
}
variable "account_number" {
  description = "The name of the service (e.g., dpc or ab2d)"
  type        = string
}
