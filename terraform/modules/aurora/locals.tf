locals {
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