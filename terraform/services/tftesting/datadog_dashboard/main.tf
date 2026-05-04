locals {
  cdap_env = contains(["sandbox", "prod"], var.env) ? "prod" : "test"
}

module "standards" {
  source    = "../../../modules/standards"
  providers = { aws = aws, aws.secondary = aws.secondary }

  app          = var.app
  env          = var.env
  root_module  = "https://github.com/CMSgov/cdap/tree/main/terraform/services/${basename(abspath(path.module))}/"
  service      = replace(basename(abspath(path.module)), "/^[0-9]+-/", "")
  ssm_root_map = { datadog = "/cdap/${local.cdap_env}/datadog/cicd/" }
}

module "datadog_dashboard" {
  source = "../../../modules/datadog_dashboard"
  app    = module.standards.app

  custom_widgets = [
    {
      # Standard timeseries showing average CPU utilization across all ECS clusters for the application
      type         = "timeseries"
      title        = "TEST DYNAMIC WIDGET ecs.cpuutilization"
      query        = "avg:aws.ecs.cpuutilization{application:${module.standards.app}, $env} by {clustername}" #include $env for filtering provided by default dashboard template
      display_type = "line"
    },
    {
      # A big number widget showing the total number of running services across all clusters
      type      = "query_value"
      title     = "Total Running Services"
      query     = "avg:aws.ecs.service.running{application:${module.standards.app}, $env}" #include $env for filtering provided by default dashboard template
      precision = 0
    },
    {
      # A ranked list of the top s3 buckets by object count for the application
      type  = "toplist"
      title = "Top s3 Buckets by Object Count"
      query = "avg:aws.s3.number_of_objects{application:${module.standards.app}, $env} by {bucketname}" #include $env for filtering provided by default dashboard template
    }
  ]

  # Opt-out of unused default infrastructure widgets
  enable_default_widgets = {
    lambda = true
    aurora = true
    sns    = true
    alb    = true
    s3     = true
    ecs    = true
  }

}
