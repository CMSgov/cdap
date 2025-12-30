variable "app" {
  description = "The application name (ab2d, bcda, dpc, cdap)"
  type        = string
  validation {
    condition     = contains(["ab2d", "bcda", "dpc", "cdap"], var.app)
    error_message = "Valid value for app is ab2d, bcda, dpc, or cdap."
  }
}

variable "env" {
  description = "The application environment (dev, test, sandbox, prod, mgmt)"
  type        = string
  validation {
    condition     = contains(["dev", "test", "sandbox", "prod", "mgmt"], var.env)
    error_message = "Valid value for env is dev, test, sandbox, prod, or mgmt."
  }
}

variable "name" {
  description = "Name for the S3 bucket"
  type        = string
}

variable "cross_account_read_roles" {
  description = "Roles in other accounts that need read access to this S3 bucket"
  type        = list(any)
  default     = []
}

variable "ssm_parameter" {
  description = "SSM Parameter path for bucket output"
  type        = string
  default     = null
}

variable "create_write_policy" {
    description = "When true, will generate a policy allowing writing objects to the bucket. Use with aws_iam_role_policy_attachment to grant access to resources in other modules"
    type = bool
    default = false
 }

variable "create_read_policy" {
    description = "When true, will generate a policy allowing reading objects from the bucket. Use with aws_iam_role_policy_attachment to grant access to resources in other modules."
    type = bool
    default = false
 }

variable "create_delete_policy" {
    description = "When true, will generate a policy allowing deletion of objects from the bucket. Use with aws_iam_role_policy_attachment to grant access to resources in other modules."
    type = bool
    default = false
 }
