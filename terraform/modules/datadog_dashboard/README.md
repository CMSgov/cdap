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