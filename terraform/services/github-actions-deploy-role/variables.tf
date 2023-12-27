variable "app_team" {
  description = "The application team (ab2d, bcda, dpc)"
  type        = string
  validation {
    condition     = contains(["ab2d", "bcda", "dpc"], var.app_team)
    error_message = "Valid value for app_team is ab2d, bcda, or dpc."
  }
}

variable "app_env" {
  description = "The application environment (dev, test, mgmt, sbx, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "test", "mgmt", "sbx", "prod"], var.app_env)
    error_message = "Valid value for app_env is dev, test, mgmt, sbx, or prod."
  }
}

variable "runner_arn" {
  description = "The arn for the runner role in the mgmt account that may assume this role"
  type        = string
}
