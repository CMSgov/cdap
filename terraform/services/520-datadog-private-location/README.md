Establishes a Datadog private location (synthetics test runner) within CDAP's VPCs.
Teams can point their synthetics tests at this PL via its ID parameter in SSM: /cdap/${env}/datadog/nonsensitive/private_location_config_id
This service's security groups allow outbound traffic from the PL worker to API teams' app VPCs.
The PL uses outbound traffic only for communicating with Datadog and running synthetics tests.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_datadog"></a> [datadog](#requirement\_datadog) | ~>4.4 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.52.0 |

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
| [aws_vpc.app](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/vpc) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_env"></a> [env](#input\_env) | The application environment (test, prod) | `string` | n/a | yes |

## Outputs

No outputs.
<!-- END_TF_DOCS -->
