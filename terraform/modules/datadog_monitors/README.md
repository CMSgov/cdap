# Monitors

Monitors are tag-scoped to a specific `app` and `env`, and use Datadog's `by {}` grouping
to alert independently per resource (e.g., per ECS service, per Lambda function, per SQS queue)
without requiring teams to enumerate their resources explicitly.

The `by {dimension}` clause (e.g., `by {servicename}`, `by {functionname}`) means a single
monitor resource evaluates independently per resource, even though we set up just one tofu resource.

## Shadow mode
- Monitors are **active and evaluating** against real metrics 
- They are **visible in the Datadog UI** under Monitors --> Manage Monitors (filter by `app:<your-app>` and `env:<your-env>`)
- They will **not send any notifications**
- All monitors are tagged `shadow-mode:true` for easy filtering in the Datadog UI

## Configuration

This module is config-driven. The consuming service merges a `defaults.yml` baseline with
per-environment overrides in `<env>.yml`. Only specify values you want to change, everything else falls
through from the defaults. An example of all the settings you can change is in [Link Text](cdap/terraform/services/530-cdap-datadog-monitors/default.yml).
Even if an AWS service's monitors are not enabled or a default.yml is not used, the default values are set.

### Enabling and Disabling Service Monitors

Each service group can be independently enabled or disabled via the `enabled` block.
Disable a service if your application does not use it:

```yaml
enabled:
  lambda: false     # disable if your app does not run lambdas
  rds: false     # disable if not hosting RDS
```

## Notification Channels 
Add your team's notification targets under notifications.channels in your default or environment config. 
The global primary channel is always included, your specific channels add on top.
Suggestion is to set up your slack channel as your global primary, and add victorops for prod. 

## Thresholds 
Each service block exposes threshold values that control when monitors fire.
All thresholds have defaults. You can override what differs for your environment or application.
Changes will apply to all AWS services within your app. 

## notify_no_data / Expected Execution Monitors

Each service block includes notify_no_data and no_data_timeframe_minutes fields, defaulting to false / 10. 
These are automatically suppressed when shadow_mode: true.

For endpoint specific notifications based on no data, provide dedicated monitors 
via the `additional_monitors` variable.

## RDS Deadlocks 
The deadlock monitor requires Enhanced Monitoring or Performance Insights to be enabled on your Aurora cluster.
If neither is enabled, set rds.deadlocks_enabled: false to suppress the monitor.

## S3 Request Metrics
S3 request metrics (s3_http_response_4xx, s3_http_response_5xx) must be enabled per bucket. 
Monitors for buckets without request metrics enabled will remain in a no-data state.


# Example Implementations 

## Thorough example 
Provided in [Link Text](cdap/terraform/services/530-cdap-datadog-monitors/main.tf), this will inherit from yaml files.

## Super simple example
Inherits all defaults. 

```
module "datadog_monitors" {
  source = "../../modules/datadog_monitors"
  app    = "example-app"
  env    = "prod"
  notify = "@slack-our-team-alerts @victorops-our-team-alerts"

  monitor_config = {
    shadow_mode = false
    enabled = {
      ecs = false
    }
  }
}
```

<!-- BEGIN_TF_DOCS -->
<!--WARNING: GENERATED CONTENT with terraform-docs, e.g.
     'terraform-docs --config "$(git rev-parse --show-toplevel)/.terraform-docs.yml" .'
     Manually updating sections between TF_DOCS tags may be overwritten.
     See https://terraform-docs.io/user-guide/configuration/ for more information.
-->
## Providers

| Name | Version |
|------|---------|
| <a name="provider_datadog"></a> [datadog](#provider\_datadog) | ~>4.4 |

<!--WARNING: GENERATED CONTENT with terraform-docs, e.g.
     'terraform-docs --config "$(git rev-parse --show-toplevel)/.terraform-docs.yml" .'
     Manually updating sections between TF_DOCS tags may be overwritten.
     See https://terraform-docs.io/user-guide/configuration/ for more information.
-->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_datadog"></a> [datadog](#requirement\_datadog) | ~>4.4 |

<!--WARNING: GENERATED CONTENT with terraform-docs, e.g.
     'terraform-docs --config "$(git rev-parse --show-toplevel)/.terraform-docs.yml" .'
     Manually updating sections between TF_DOCS tags may be overwritten.
     See https://terraform-docs.io/user-guide/configuration/ for more information.
-->
## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_app"></a> [app](#input\_app) | The application name (ab2d, bbapi, bcda, cdap dpc) | `string` | n/a | yes |
| <a name="input_env"></a> [env](#input\_env) | Deployment environment (dev, test, sandbox, stage, prod) | `string` | n/a | yes |
| <a name="input_notify"></a> [notify](#input\_notify) | Composed notification string — all @mention handles joined with spaces | `string` | n/a | yes |
| <a name="input_monitor_config"></a> [monitor\_config](#input\_monitor\_config) | n/a | <pre>object({<br/>    shadow_mode = optional(bool, true)<br/>    enabled = optional(object({<br/>      ecs    = optional(bool, true)<br/>      sqs    = optional(bool, true)<br/>      sns    = optional(bool, true)<br/>      lambda = optional(bool, true)<br/>      s3     = optional(bool, true)<br/>      rds    = optional(bool, true)<br/>    }), {})<br/>    ecs = optional(object({<br/>      cpu_threshold             = optional(number, 85)<br/>      memory_threshold          = optional(number, 85)<br/>      notify_no_data            = optional(bool, false)<br/>      no_data_timeframe_minutes = optional(number, 10)<br/>      timeframe                 = optional(string, "last_10m")<br/>    }), {})<br/>    sqs = optional(object({<br/>      dlq_message_threshold     = optional(number, 1)<br/>      max_message_age_seconds   = optional(number, 300)<br/>      notify_no_data            = optional(bool, false)<br/>      no_data_timeframe_minutes = optional(number, 10)<br/>      timeframe                 = optional(string, "last_5m")<br/>    }), {})<br/>    sns = optional(object({<br/>      failed_notification_threshold = optional(number, 5)<br/>      notify_no_data                = optional(bool, false)<br/>      no_data_timeframe_minutes     = optional(number, 10)<br/>      timeframe                     = optional(string, "last_5m")<br/><br/>    }), {})<br/>    lambda = optional(object({<br/>      error_rate_threshold      = optional(number, 5)<br/>      throttle_threshold        = optional(number, 10)<br/>      duration_p99_threshold_ms = optional(number, 8000)<br/>      notify_no_data            = optional(bool, false)<br/>      no_data_timeframe_minutes = optional(number, 10)<br/>      timeframe                 = optional(string, "last_5m")<br/><br/>    }), {})<br/>    s3 = optional(object({<br/>      http_response_4xx_threshold = optional(number, 50)<br/>      http_response_5xx_threshold = optional(number, 10)<br/>      notify_no_data              = optional(bool, false)<br/>      no_data_timeframe_minutes   = optional(number, 10)<br/>      timeframe                   = optional(string, "last_5m")<br/><br/>    }), {})<br/>    rds = optional(object({<br/>      cpu_threshold                = optional(number, 85)<br/>      freeable_memory_threshold_mb = optional(number, 256)<br/>      db_connections_threshold     = optional(number, 200)<br/>      replica_lag_seconds          = optional(number, 30)<br/>      deadlock_threshold           = optional(number, 1)<br/>      deadlocks_enabled            = optional(bool, true)<br/>      notify_no_data               = optional(bool, false)<br/>      no_data_timeframe_minutes    = optional(number, 10)<br/>      timeframe                    = optional(string, "last_10m")<br/><br/>    }), {})<br/>  })</pre> | `{}` | no |
| <a name="input_custom_monitors"></a> [custom\_monitors](#input\_custom\_monitors) | Custom monitors to create. Module handles notify, shadow\_mode, and base\_tags automatically. Use create to conditionally create the monitor (i.e. on only certain environments)--use this option sparingly. | <pre>list(object({<br/>    name    = string<br/>    type    = optional(string, "metric alert")<br/>    message = string<br/>    query   = string<br/>    thresholds = object({<br/>      critical          = number<br/>      warning           = optional(number)<br/>      critical_recovery = optional(number)<br/>      warning_recovery  = optional(number)<br/>    })<br/>    on_missing_data     = optional(string, "default")<br/>    require_full_window = optional(bool, true)<br/>    tags                = optional(list(string), [])<br/>    create              = optional(bool, true)<br/>  }))</pre> | `[]` | no |

<!--WARNING: GENERATED CONTENT with terraform-docs, e.g.
     'terraform-docs --config "$(git rev-parse --show-toplevel)/.terraform-docs.yml" .'
     Manually updating sections between TF_DOCS tags may be overwritten.
     See https://terraform-docs.io/user-guide/configuration/ for more information.
-->
## Modules

No modules.

<!--WARNING: GENERATED CONTENT with terraform-docs, e.g.
     'terraform-docs --config "$(git rev-parse --show-toplevel)/.terraform-docs.yml" .'
     Manually updating sections between TF_DOCS tags may be overwritten.
     See https://terraform-docs.io/user-guide/configuration/ for more information.
-->
## Resources

| Name | Type |
|------|------|
| [datadog_monitor.ecs_cpu_high](https://registry.terraform.io/providers/DataDog/datadog/latest/docs/resources/monitor) | resource |
| [datadog_monitor.ecs_memory_high](https://registry.terraform.io/providers/DataDog/datadog/latest/docs/resources/monitor) | resource |
| [datadog_monitor.lambda_duration](https://registry.terraform.io/providers/DataDog/datadog/latest/docs/resources/monitor) | resource |
| [datadog_monitor.lambda_error_rate](https://registry.terraform.io/providers/DataDog/datadog/latest/docs/resources/monitor) | resource |
| [datadog_monitor.lambda_throttles](https://registry.terraform.io/providers/DataDog/datadog/latest/docs/resources/monitor) | resource |
| [datadog_monitor.rds_cpu_high](https://registry.terraform.io/providers/DataDog/datadog/latest/docs/resources/monitor) | resource |
| [datadog_monitor.rds_db_connections_high](https://registry.terraform.io/providers/DataDog/datadog/latest/docs/resources/monitor) | resource |
| [datadog_monitor.rds_deadlocks](https://registry.terraform.io/providers/DataDog/datadog/latest/docs/resources/monitor) | resource |
| [datadog_monitor.rds_freeable_memory_low](https://registry.terraform.io/providers/DataDog/datadog/latest/docs/resources/monitor) | resource |
| [datadog_monitor.rds_replica_lag_high](https://registry.terraform.io/providers/DataDog/datadog/latest/docs/resources/monitor) | resource |
| [datadog_monitor.s3_http_response_4xx](https://registry.terraform.io/providers/DataDog/datadog/latest/docs/resources/monitor) | resource |
| [datadog_monitor.s3_http_response_5xx](https://registry.terraform.io/providers/DataDog/datadog/latest/docs/resources/monitor) | resource |
| [datadog_monitor.sns_failed_notifications](https://registry.terraform.io/providers/DataDog/datadog/latest/docs/resources/monitor) | resource |
| [datadog_monitor.sqs_dlq_messages_visible](https://registry.terraform.io/providers/DataDog/datadog/latest/docs/resources/monitor) | resource |
| [datadog_monitor.sqs_message_age](https://registry.terraform.io/providers/DataDog/datadog/latest/docs/resources/monitor) | resource |

<!--WARNING: GENERATED CONTENT with terraform-docs, e.g.
     'terraform-docs --config "$(git rev-parse --show-toplevel)/.terraform-docs.yml" .'
     Manually updating sections between TF_DOCS tags may be overwritten.
     See https://terraform-docs.io/user-guide/configuration/ for more information.
-->
## Outputs

| Name | Description |
|------|-------------|
| <a name="output_monitor_ids"></a> [monitor\_ids](#output\_monitor\_ids) | All Datadog monitor IDs created by this module, grouped by service |
<!-- END_TF_DOCS -->