locals {
  defaults   = yamldecode(file("config/defaults.yml"))
  env_config = yamldecode(file("config/${var.env}.yml"))

  monitor_config = {
    for key in distinct(concat(keys(local.defaults), keys(local.env_config))) :
    key => try(
      # Attempt map merge (works if both values are map/object-typed)
      merge(
        lookup(local.defaults, key, {}),
        lookup(local.env_config, key, {})
      ),
      # Fallback to scalar: env wins, then default
      lookup(local.env_config, key, lookup(local.defaults, key, null))
    )
  }
}

###################
# Common Monitors #
###################

module "common_datadog_monitors" {
  source = "../../modules/datadog_monitors"

  app              = "cdap"
  env              = var.env
  monitor_config   = local.monitor_config
  custom_monitors  = concat(local.codebuild_custom_monitors, local.synthetics_custom_monitors)
  synthetics_tests = module.synthetics.synthetics_tests
}

##########################
# CDAP Specific Monitors #
##########################

locals {
  codebuild_repos = [
    "ab2d",
    "ab2d-website",
    "bcda-app",
    "bcda-ssas-app",
    "bcda-static-site",
    "cdap",
    "dpc-app",
    "dpc-ops",
    "dpc-static-site",
  ]

  codebuild_custom_monitors = flatten([
    for repo in local.codebuild_repos : [
      {
        name    = "[${upper(module.platform.account_env_suffix)}] [${repo}] CodeBuild — Failed Builds"
        type    = "metric alert"
        message = "CodeBuild project ${repo}-${module.platform.account_env_suffix} has failing builds."
        # fill missing windows with 0
        query = "sum(last_30m):sum:aws.codebuild.failed_builds{projectname:${repo}-${module.platform.account_env_suffix}}.fill(zero, 1800).as_count() > 1"
        thresholds = {
          critical = 1
        }
        # TODO does this make sense for CDAP?
        on_missing_data     = "default"
        require_full_window = false
      },
      {
        name    = "[${upper(module.platform.account_env_suffix)}] [${repo}] CodeBuild — Builds Backing Up in Queue"
        type    = "metric alert"
        message = "CodeBuild project ${repo}-${module.platform.account_env_suffix} builds are queuing — runners may be unavailable."
        # fill missing windows with 0
        query = "avg(last_10m):avg:aws.codebuild.queued_duration{projectname:${repo}-${module.platform.account_env_suffix}}.fill(zero, 600) > 120"
        thresholds = {
          critical = 120
          warning  = 72
        }
        # TODO does this make sense for CDAP?
        on_missing_data     = "default"
        require_full_window = false
      }
    ]
  ])

  synthetics_custom_monitors = try(local.monitor_config.enabled.synthetics, false) ? [
    for test in module.synthetics.synthetics_tests : {
      name    = "[${upper(module.platform.account_env_suffix)}] [cdap] Synthetics — ${test.name} Failed"
      type    = "metric alert"
      message = "Synthetic test ${test.name} has failed in ${module.platform.account_env_suffix}."
      query   = "sum(last_5m):sum:datadog.synthetics.test_runs{public_id:${test.public_id},result:failed}.as_count() > 0"
      thresholds = {
        critical = 0
      }
      # TODO does this make sense for CDAP?
      on_missing_data     = "default"
      require_full_window = false
    }
  ] : []
}
