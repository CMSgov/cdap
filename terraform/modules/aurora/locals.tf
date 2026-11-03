locals {
  aurora_engine       = "aurora-postgresql"
  aurora_family       = "${local.aurora_engine}${local.major_version}"
  major_version       = split(".", var.engine_version)[0]
  security_group_name = coalesce(var.security_group_override, "${local.service_prefix}-db")
  service_prefix      = "${var.platform.app}-${var.platform.env}"

  cluster_identifier = coalesce(var.cluster_identifier, local.service_prefix)
  kms_key_id         = coalesce(var.kms_key_override, var.platform.kms_alias_primary.target_key_arn)

  # Name is dictated by RDS log exports. It writes only to this group
  postgresql_log_group_name = "/aws/rds/cluster/${local.cluster_identifier}/postgresql"

  default_cluster_parameters = [
    {
      apply_method = "immediate"
      name         = "rds.force_ssl"
      value        = "1"
    },
    {
      apply_method = "pending-reboot"
      name         = "shared_preload_libraries"
      value        = "pg_stat_statements,pg_cron"
    },
    # Durable record of database logins, including breakglass use
    {
      apply_method = "immediate"
      name         = "log_connections"
      value        = "1"
    },
    {
      apply_method = "immediate"
      name         = "log_disconnections"
      value        = "1"
    }
  ]
}
