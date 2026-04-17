locals {
  app_name = "ab2d"
}

module "datadog_dashboard" {
  source = "../../../modules/datadog_dashboard"
  app    = local.app_name

  custom_widgets = [
    {
      # Standard timeseries showing average CPU utilization across all ECS clusters for the application
      type         = "timeseries"
      title        = "TEST DYNAMIC WIDGET ecs.cpuutilization"
      query        = "avg:aws.ecs.cpuutilization{application:${local.app_name}} by {clustername}"
      display_type = "line"
    },
    {
      # A big number widget showing the total number of running services across all clusters
      type      = "query_value"
      title     = "Total Running Services"
      query     = "avg:aws.ecs.service.running{application:${local.app_name}, $env}"
      precision = 0
    },
    {
      # A ranked list of the top s3 buckets by object count for the application
      type  = "toplist"
      title = "Top s3 Buckets by Object Count"
      query = "avg:aws.s3.number_of_objects{application:${local.app_name}} by {bucketname}"
    }
  ]

  # Opt-out of unused default infrastructure widgets
  enable_default_widgets = {
    lambda = true
    aurora = true
    sns    = true
    elb    = true
    s3     = true
    ecs    = true
  }

}
