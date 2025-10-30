locals {
  aurora_engine       = "aurora-postgresql"
  aurora_family       = "${local.aurora_engine}${local.major_version}"
  major_version       = split(".", var.engine_version)[0]
  security_group_name = coalesce(var.security_group_override, "${local.service_prefix}-db")
  service_prefix      = "${var.platform.app}-${var.platform.env}"

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
    }
  ]
}
