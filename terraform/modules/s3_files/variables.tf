variable "platform" {
  description = "Object representing the CDAP platform module."
  type = object({
    app               = string
    env               = string
    kms_alias_primary = object({ target_key_arn = string })
    vpc_id            = string
    private_subnets   = map(object({ id = string }))
  })
}

variable "name" {
  description = "Identifier suffix for the S3 Files resources (e.g. 'attribution-import-files')"
  type        = string
}

variable "bucket_arn" {
  description = "Target S3 bucket ARN to mount"
  type        = string
}

variable "read_only" {
  description = "Whether the file system access should enforce read-only operations. Defaults to true."
  type        = bool
  default     = true
}

variable "allowed_security_group_ids" {
  description = "List of security group IDs permitted to mount the file system over NFS (TCP port 2049). Use this when client security groups are known upfront. When connecting to modules that consume this module's outputs (e.g. modules/function), define standalone rules in the caller to avoid dependency cycles."
  type        = list(string)
  default     = []
}
