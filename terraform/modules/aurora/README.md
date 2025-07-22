<!-- BEGIN_TF_DOCS -->
<!--WARNING: GENERATED CONTENT with terraform-docs, e.g.
     'terraform-docs --config "$(git rev-parse --show-toplevel)/.terraform-docs.yml" .'
     Manually updating sections between TF_DOCS tags may be overwritten.
     See https://terraform-docs.io/user-guide/configuration/ for more information.
-->
## Requirements

No requirements.

<!--WARNING: GENERATED CONTENT with terraform-docs, e.g.
     'terraform-docs --config "$(git rev-parse --show-toplevel)/.terraform-docs.yml" .'
     Manually updating sections between TF_DOCS tags may be overwritten.
     See https://terraform-docs.io/user-guide/configuration/ for more information.
-->
## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_backup_window"></a> [backup\_window](#input\_backup\_window) | Daily time range during which automated backups are created if automated backups are enabled in UTC, e.g. `04:00-09:00` | `string` | n/a | yes |
| <a name="input_instance_class"></a> [instance\_class](#input\_instance\_class) | Aurora cluster instance class | `string` | n/a | yes |
| <a name="input_maintenance_window"></a> [maintenance\_window](#input\_maintenance\_window) | Weekly time range during which system maintenance can occur in UTC, e.g. `wed:04:00-wed:04:30` | `string` | n/a | yes |
| <a name="input_password"></a> [password](#input\_password) | The database's primary/master credentials password | `string` | n/a | yes |
| <a name="input_platform"></a> [platform](#input\_platform) | Object that describes standardized platform values. | `any` | n/a | yes |
| <a name="input_username"></a> [username](#input\_username) | The database's primary/master credentials username | `string` | n/a | yes |
| <a name="input_aws_backup_tag"></a> [aws\_backup\_tag](#input\_aws\_backup\_tag) | Override for the standard | `string` | `"4hr7_w90"` | no |
| <a name="input_backup_retention_period"></a> [backup\_retention\_period](#input\_backup\_retention\_period) | Days to retain backups for. | `number` | `1` | no |
| <a name="input_cluster_identifier"></a> [cluster\_identifier](#input\_cluster\_identifier) | Override for the aurora cluster identifier | `string` | `null` | no |
| <a name="input_cluster_instance_parameters"></a> [cluster\_instance\_parameters](#input\_cluster\_instance\_parameters) | A list of objects containing the values for apply\_method, name, and value that corresponds to the instance-level prameters. | <pre>list(object({<br/>    apply_method = string<br/>    name         = string<br/>    value        = any<br/>  }))</pre> | `[]` | no |
| <a name="input_cluster_parameters"></a> [cluster\_parameters](#input\_cluster\_parameters) | A list of objects containing the values for apply\_method, name, and value that corresponds to the cluster-level prameters. | <pre>list(object({<br/>    apply_method = string<br/>    name         = string<br/>    value        = any<br/>  }))</pre> | `[]` | no |
| <a name="input_deletion_protection"></a> [deletion\_protection](#input\_deletion\_protection) | If the DB cluster should have deletion protection enabled. | `bool` | `true` | no |
| <a name="input_engine_version"></a> [engine\_version](#input\_engine\_version) | Selected engine version for either RDS DB Instance or RDS Aurora DB Cluster. | `string` | `"16.8"` | no |
| <a name="input_instance_count"></a> [instance\_count](#input\_instance\_count) | Desired number of cluster instances | `number` | `1` | no |
| <a name="input_kms_key_override"></a> [kms\_key\_override](#input\_kms\_key\_override) | Override to the platform-managed KMS key | `string` | `null` | no |
| <a name="input_monitoring_interval"></a> [monitoring\_interval](#input\_monitoring\_interval) | [monitoring\_interval](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/rds_cluster#monitoring_interval-1). Interval, in seconds, in seconds, between points when Enhanced Monitoring metrics are collected for the DB cluster. | `number` | `15` | no |
| <a name="input_monitoring_role_arn"></a> [monitoring\_role\_arn](#input\_monitoring\_role\_arn) | ARN for the IAM role that permits RDS to send enhanced monitoring metrics to CloudWatch Logs. | `string` | `null` | no |
| <a name="input_snapshot_identifier"></a> [snapshot\_identifier](#input\_snapshot\_identifier) | When provided, cluster is provisioned using the specified cluster snapshot identifier. | `string` | `null` | no |
| <a name="input_storage_type"></a> [storage\_type](#input\_storage\_type) | Aurora cluster [storage\_type](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/rds_cluster#storage_type-1) | `string` | `""` | no |
| <a name="input_vpc_security_group_ids"></a> [vpc\_security\_group\_ids](#input\_vpc\_security\_group\_ids) | Additional security group ids for attachment to the database security group. | `list(string)` | `[]` | no |

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
| [aws_db_parameter_group.aurora](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_parameter_group) | resource |
| [aws_db_subnet_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_subnet_group) | resource |
| [aws_rds_cluster.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/rds_cluster) | resource |
| [aws_rds_cluster_instance.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/rds_cluster_instance) | resource |
| [aws_rds_cluster_parameter_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/rds_cluster_parameter_group) | resource |
| [aws_security_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_vpc_security_group_egress_rule.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |

<!--WARNING: GENERATED CONTENT with terraform-docs, e.g.
     'terraform-docs --config "$(git rev-parse --show-toplevel)/.terraform-docs.yml" .'
     Manually updating sections between TF_DOCS tags may be overwritten.
     See https://terraform-docs.io/user-guide/configuration/ for more information.
-->
## Outputs

| Name | Description |
|------|-------------|
| <a name="output_aurora_cluster"></a> [aurora\_cluster](#output\_aurora\_cluster) | n/a |
| <a name="output_aurora_instances"></a> [aurora\_instances](#output\_aurora\_instances) | n/a |
| <a name="output_security_group"></a> [security\_group](#output\_security\_group) | n/a |
<!-- END_TF_DOCS -->