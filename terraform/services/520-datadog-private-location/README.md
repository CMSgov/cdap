<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_datadog"></a> [datadog](#requirement\_datadog) | ~>4.4 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.50.0 |
| <a name="provider_datadog"></a> [datadog](#provider\_datadog) | 4.12.1 |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_cdap_cluster"></a> [cdap\_cluster](#module\_cdap\_cluster) | ../../modules/cluster | n/a |
| <a name="module_ecs_datadog_synthetics"></a> [ecs\_datadog\_synthetics](#module\_ecs\_datadog\_synthetics) | ../../modules/service | n/a |
| <a name="module_platform"></a> [platform](#module\_platform) | ../../modules/platform | n/a |

## Resources

| Name | Type |
| ---- | ---- |
| [aws_vpc_security_group_egress_rule.private_location_app_vpcs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [datadog_synthetics_test.cdap_test_private_location_connectivity](https://registry.terraform.io/providers/DataDog/datadog/latest/docs/resources/synthetics_test) | resource |
| [aws_vpc.app](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/vpc) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_env"></a> [env](#input\_env) | The application environment (test, prod) | `string` | n/a | yes |

## Outputs

No outputs.
<!-- END_TF_DOCS -->