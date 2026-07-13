## Description
This module provides teams with a Datadog dashboard that provides metrics and high-level observability for common DASG architectures. The dashboard displays metrics for Lambda, Aurora, SNS, S3, ECS, and ALB resources by default. Teams can opt-out of widgets that are not relevant to their app.

Child modules can also define custom widgets via a dynamic block. In the future, this module can also be expanded to cover additional default widgets to support future architectures. For an example child module implementation, refer to services/tftesting/datadog_dashboard/main.tf

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
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~>6.0 |
| <a name="requirement_datadog"></a> [datadog](#requirement\_datadog) | ~>4.4 |

<!--WARNING: GENERATED CONTENT with terraform-docs, e.g.
     'terraform-docs --config "$(git rev-parse --show-toplevel)/.terraform-docs.yml" .'
     Manually updating sections between TF_DOCS tags may be overwritten.
     See https://terraform-docs.io/user-guide/configuration/ for more information.
-->
## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_app"></a> [app](#input\_app) | The application name (ab2d, bb, bcda, cdap dpc) | `string` | n/a | yes |
| <a name="input_runbook_url"></a> [runbook\_url](#input\_runbook\_url) | URL where on-call engineers can find actions to remediate issues, including escalation. | `string` | n/a | yes |
| <a name="input_apm_primary_operation"></a> [apm\_primary\_operation](#input\_apm\_primary\_operation) | Primary operation / span name to use for APM metrics in the dashboard. | `string` | `"http.request"` | no |
| <a name="input_custom_widgets"></a> [custom\_widgets](#input\_custom\_widgets) | Custom widgets to add to the dashboard. See README for details. | `list(any)` | `[]` | no |
| <a name="input_enable_default_widgets"></a> [enable\_default\_widgets](#input\_enable\_default\_widgets) | Toggle default infrastructure widgets on or off for the dashboard. | <pre>object({<br/>    monitors = optional(bool, true)<br/>    ecs      = optional(bool, true)<br/>    lambda   = optional(bool, true)<br/>    alb      = optional(bool, true)<br/>    sns      = optional(bool, true)<br/>    sqs      = optional(bool, true)<br/>    aurora   = optional(bool, true)<br/>    s3       = optional(bool, true)<br/>    apm      = optional(bool, true)<br/>  })</pre> | `{}` | no |
| <a name="input_name_rewrite"></a> [name\_rewrite](#input\_name\_rewrite) | Allows for the creation of unique dashboards per application. Currently used only for development. | `string` | `null` | no |
| <a name="input_widget_live_spans"></a> [widget\_live\_spans](#input\_widget\_live\_spans) | Live span overrides for specific dashboard sections. Valid values: 5m, 10m, 15m, 30m, 1h, 4h, 1d, 2d, 1w, 1mo | <pre>object({<br/>    current = optional(string, "15m") # short window for point-in-time accuracy<br/>    ecs     = optional(string, "1d")  # ECS utilization, events, restarts<br/>    apm     = optional(string, "1h")  # Request rate, latency, error rate<br/>    alb     = optional(string, "1d")  # Request counts, response times<br/>    sqs     = optional(string, "4h")  # Message counts, DLQ depth<br/>    sns     = optional(string, "4h")  # Published, delivered, failed<br/>    lambda  = optional(string, "2d")  # Invocations, errors, duration<br/>    aurora  = optional(string, "4h")  # CPU, IOPS, latency, replica lag<br/>    s3      = optional(string, "1w")  # S3 metrics update daily — needs wide window<br/>  })</pre> | `{}` | no |

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
| [datadog_dashboard.application_metrics_dashboard](https://registry.terraform.io/providers/DataDog/datadog/latest/docs/resources/dashboard) | resource |

<!--WARNING: GENERATED CONTENT with terraform-docs, e.g.
     'terraform-docs --config "$(git rev-parse --show-toplevel)/.terraform-docs.yml" .'
     Manually updating sections between TF_DOCS tags may be overwritten.
     See https://terraform-docs.io/user-guide/configuration/ for more information.
-->
## Outputs

No outputs.
<!-- END_TF_DOCS -->
