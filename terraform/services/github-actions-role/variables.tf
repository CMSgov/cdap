variable "runner_arn" {
  description = "The arn for the runner that will assume the role"
  type        = string
}

variable "oidc_provider_arn" {
  description = "The arn for the OIDC provider that will allow the role to be assumed"
  type        = string
}
