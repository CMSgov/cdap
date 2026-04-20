## Description
This module provides teams with a Datadog dashboard that provides metrics and high-level observability for
common DASG architectures. The dashboard displays metrics for Lambda, Aurora, SNS, S3, ECS, and ALB resources by default.
Teams can opt-out of widgets that are not relevant to their app.

Child modules can also define custom widgets via a dynamic block. In the future, this module can also be expanded to cover additional default
widgets to support future architectures. For an example child module implementation, refer to services/tftesting/datadog_dashboard/main.tf

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.6.0 |
| <a name="requirement_datadog"></a> [datadog](#requirement\_datadog) | ~> 3.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_datadog"></a> [datadog](#provider\_datadog) | 3.91.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [datadog_dashboard.Application_Metrics_Dashboard](https://registry.terraform.io/providers/DataDog/datadog/latest/docs/resources/dashboard) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_app"></a> [app](#input\_app) | The application name (ab2d, bcda, cdap dpc) | `string` | n/a | yes |
| <a name="input_custom_widgets"></a> [custom\_widgets](#input\_custom\_widgets) | Custom widgets to add to the dashboard. See README for details. | `list(any)` | `[]` | no |

## Outputs

No outputs.
<!-- END_TF_DOCS -->
