variable "username" {
  # deprecated  = "This will no longer be supported once APIs adopt AWS Secrets Manager manged credentials."
  description = "The database's primary/master credentials username"
  type        = string
}

variable "password" {
  # deprecated  = "This will no longer be supported once APIs adopt AWS Secrets Manager manged credentials."
  description = <<-EOT
    The database's primary/master credentials password. Required only when
    manage_master_user_password = false. Ignored (and may be omitted) when
    manage_master_user_password = true, since RDS generates and stores the
    master password in Secrets Manager instead.
  EOT
  type        = string
  default     = null
  sensitive   = true
}

variable "manage_master_user_password" {
  description = <<-EOT
    If true, RDS creates and manages the master user password in AWS
    Secrets Manager instead of using var.password. Opt-in and off by
    default -- existing username/password behavior is unchanged unless a
    team explicitly turns this on.
  EOT
  type        = bool
  default     = false
}

variable "master_password_rotation_days" {
  description = <<-EOT
    Rotation interval, in days, for the RDS-managed master user secret.
    Only applies when manage_master_user_password = true. Defaults to 0,
    which leaves automatic rotation disabled.
  EOT
  type        = number
  default     = 0
}

variable "enable_iam_database_authentication" {
  description = <<-EOT
    If true, enables the IAM database authentication capability on the
    cluster. This only makes IAM auth available -- it does not disable or
    replace username/password authentication, and no Postgres role uses it
    until a consuming terraservice grants that role `rds_iam` and attaches
    its own IAM policy scoped to that dbuser, using the cluster_resource_id
    this module publishes via SSM. Defaults to true because enabling the
    capability has no effect on teams that don't use it.
  EOT
  type        = bool
  default     = true
}

variable "platform" {
  description = "Object that describes standardized platform values."
  type        = any
}

variable "kms_key_override" { #TODO: Consider removing this all together.
  default     = null
  description = "Override to the platform-managed KMS key"
  type        = string
}

variable "instance_class" {
  description = "Aurora cluster instance class, restricted to RI instances"
  type        = string
  validation {
    condition     = contains(["db.r8g.large", "db.r8g.xlarge", "db.r8g.2xlarge"], var.instance_class)
    error_message = "Supporting instance classes that are part of DASG's 2025-2026 DB reserved instance allocation"
  }
}

variable "instance_count" {
  default     = 1
  description = "Desired number of cluster instances"
  type        = number
}

variable "vpc_security_group_ids" {
  default     = []
  description = <<-EOT
    Deprecated. Additional security group IDs to attach directly to the Aurora cluster.
    Service-level DB access should be granted via ingress rules referencing
    the published SSM parameter.
  EOT
  type        = list(string)
}

variable "maintenance_window" {
  description = "Weekly time range during which system maintenance can occur in UTC, e.g. `wed:04:00-wed:04:30`"
  type        = string
}

variable "backup_window" { #TODO: Consider removing this in favor of AWS Backups
  description = "Daily time range during which automated backups are created if automated backups are enabled in UTC, e.g. `04:00-09:00`"
  type        = string
}

variable "monitoring_interval" {
  default     = 15
  description = "The [monitoring_interval](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/rds_cluster#monitoring_interval-1) in seconds determines the time between sampling enhanced monitoring metrics for the cluster."
  type        = number
}

variable "deletion_protection" {
  default     = true
  description = "If the DB cluster should have deletion protection enabled."
  type        = bool
}

variable "snapshot_identifier" {
  default     = null
  description = "When provided, cluster is provisioned using the specified cluster snapshot identifier."
  type        = string
}

variable "monitoring_role_arn" {
  default     = null
  description = "ARN for the IAM role that permits RDS to send enhanced monitoring metrics to CloudWatch Logs."
  type        = string
}

variable "cluster_parameters" {
  default     = []
  description = "A list of objects containing the values for apply_method, name, and value that corresponds to the cluster-level prameters."
  type = list(object({
    apply_method = string
    name         = string
    value        = any
  }))
}

variable "cluster_instance_parameters" {
  default     = []
  description = "A list of objects containing the values for apply_method, name, and value that corresponds to the instance-level prameters."
  type = list(object({
    apply_method = string
    name         = string
    value        = any
  }))
}

variable "engine_version" {
  default     = "16"
  description = "Selected major engine version for either RDS DB Instance or RDS Aurora DB Cluster."
  type        = string
}

variable "backup_retention_period" {
  default     = 1
  description = "Days to retain backups for."
  type        = number
}

variable "storage_type" {
  default     = ""
  description = "Aurora cluster [storage_type](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/rds_cluster#storage_type-1)"
  type        = string
  validation {
    condition     = contains(["aurora-iopt1", ""], var.storage_type)
    error_message = "Aurora storage type only accepts 'aurora-iopt1' or an empty string ''."
  }
}

variable "cluster_identifier" {
  default     = null
  description = "Override for the aurora cluster identifier"
  type        = string
}

variable "aws_backup_tag" {
  default     = "4hr1dr_d7_w35_m90"
  description = "Override for a standard, CDAP-managed backup tag for AWS Backups"
  type        = string
}

variable "subnet_group_override" {
  default     = null
  description = "Override for the subnet group name"
  type        = string
}

variable "security_group_override" {
  default     = null
  description = "Override for the security group name"
  type        = string
}

