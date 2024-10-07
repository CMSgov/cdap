variable "app" {
  description = "The application name (ab2d, bcda, dpc)"
  type        = string
  validation {
    condition     = contains(["ab2d", "bcda", "dpc"], var.app)
    error_message = "Valid value for app is ab2d, bcda, or dpc."
  }
}

variable "env" {
  description = "The application environment (dev, test, sbx, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "test", "sbx", "prod"], var.env)
    error_message = "Valid value for env is dev, test, sbx, or prod."
  }
}

variable "aws_account_number" {}
variable "controller_sg_id" {}
variable "cpm_backup_db" {}
variable "db_allocated_storage_size" {
  description = "Total storage to be allocated to the database (in GB)"
  type        = number
  default     = 500
}
variable "db_backup_retention_period" {}
variable "db_backup_window" {}
variable "db_copy_tags_to_snapshot" {}
variable "db_identifier" {
  description = "Database identifier based on app and environment"
  type        = map(string)
  default     = {
    ab2d = {
      dev  = "ab2d-dev"
      test = "ab2d-east-impl"
      prod = "ab2d-east-prod"
      sbx  = "ab2d-sbx-sandbox"
    }
    bcda = {
      dev  = "${var.app}-${var.env}"
      test = "${var.app}-${var.env}"
      sbx  = "${var.app}-${var.env}"
      prod = "${var.app}-${var.env}"
    }
    dpc = {
      dev  = "${var.app}-${var.env}"
      test = "${var.app}-${var.env}"
      sbx  = "${var.app}-${var.env}"
      prod = "${var.app}-${var.env}"
    }
  }
}
variable "db_instance_class" {
  description = "The instance class for RDS to be hosted on, by size and type"
  type        = string
  default     = "db.m6i.2xlarge"
}
variable "db_iops" {}
variable "db_maintenance_window" {}
variable "db_multi_az" {}
variable "db_parameter_group_name" {}
variable "db_password" {}
variable "db_snapshot_id" {}
variable "db_subnet_group_name" {}
variable "db_username" {}
variable "jenkins_agent_sec_group_id" {}
variable "main_kms_key_arn" {}
variable "parent_env" {}
variable "postgres_engine_version" {
  description = "Version of Postgres to use for the RDS database"
  type        = string
  default     = "15.5"
}
variable "private_subnet_a_id" {}
variable "private_subnet_b_id" {}
variable "region" {}
variable "vpc_id" {}
