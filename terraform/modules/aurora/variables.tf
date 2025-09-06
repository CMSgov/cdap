variable "username" {
  # deprecated  = "This will no longer be supported once APIs adopt AWS Secrets Manager manged credentials." #TODO opentofu only
  description = "The database's primary/master credentials username"
  type        = string
}

variable "password" {
  # deprecated  = "This will no longer be supported once APIs adopt AWS Secrets Manager manged credentials." #TODO opentofu only
  description = "The database's primary/master credentials password"
  type        = string
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
  description = "Additional security group ids for attachment to the database security group."
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
  default     = "16.8"
  description = "Selected engine version for either RDS DB Instance or RDS Aurora DB Cluster."
  type        = string
}

variable "backup_retention_period" { #TODO: Consider removing this in favor of AWS Backups
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
  default     = "4Hours1_Daily7_Weekly35_Monthly90"
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
