variable "runner_arn" {
  description = "The arn for the runner role in the mgmt account that may assume this role"
  type        = string
}

variable "oidc_provider_arn" {
  description = "The arn for the OIDC provider that may allow this role to be assumed from GitHub runners"
  type        = string
}
