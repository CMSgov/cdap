# Aurora Child Module
This module creates the minimum set of semi-opinionated resources directly supporting creation and ongoing maintenance of an [Amazon Aurora DB Cluster](https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/CHAP_Aurora.html) with ephemeral environment support.
For a complete list of resources managed by this module, please see the [Resources section](#user-content-resources) below.

## Important Usage Notes

### Platform Module Expectations
While emerging standardized `platform` isn't strictly required, usage is strongly recommended. **this** module expects the input variable `var.platform` as an object that includes the following, prescriptive fields:
- `var.platform.is_ephemeral_env`
- `var.platform.security_groups.cmscloud-security-tools.id`
- `var.platform.security_groups.remote-management.id`
- `var.platform.security_groups.zscaler-private.id`
- `var.platform.app`
- `var.platform.env`
- `var.platform.vpc_id`
- `var.platform.kms_alias_primary.target_key_arn`

### Cluster and Cluster Instance Parameters
At the time of this writing, this module does not set any specific parameters for the Cluster nor Cluster Instance Parameter Groups.
While the list of parameters can be highly contextual and require tuning and updates to an application's usage of the datastore, the following cluster instance parameters are modest and have some dramatic performance implications to such an extent they may well find their way into **this** module's definition itself as part of a _sensible default_:

``` hcl
cluster_instance_parameters = [
  {
    apply_method = "immediate"
    name         = "random_page_cost"
    value        = "1.1"
  },
  {
    apply_method = "immediate"
    name         = "work_mem"
    value        = "32768"
  },
  {
    apply_method = "immediate"
    name         = "statement_timeout"
    value        = "1200000"
  },
]
```

## Example Usage

``` hcl
locals {
  default_tags = module.platform.default_tags
  env          = terraform.workspace
  service      = "core"
}

# declare the `platform` module to be used as an input to the `db` module below
module "platform" {
  source    = "git::https://github.com/CMSgov/cdap.git//terraform/modules/platform?ref=PLT-1099"
  providers = { aws = aws, aws.secondary = aws.secondary }

  app         = local.app
  env         = local.env
  root_module = "https://github.com/CMSgov/ab2d/tree/main/ops/services/10-core"
  service     = local.service
  ssm_root_map = {
    core = "/ab2d/${local.env}/core/"
  }
}

# declare the `db` module, defining the desired input variables
module "db" {
  source = "github.com/CMSgov/cdap//terraform/modules/aurora"

  backup_retention_period = module.platform.is_ephemeral_env ? 1 : 7
  deletion_protection     = !module.platform.is_ephemeral_env
  password                = module.platform.ssm.core.database_password.value
  username                = module.platform.ssm.core.database_user.value
  platform                = module.platform

  cluster_instance_parameters = [
    {
      apply_method = "immediate"
      name         = "random_page_cost"
      value        = "1.1"
    },
    {
      apply_method = "immediate"
      name         = "work_mem"
      value        = "32768"
    },
    {
      apply_method = "immediate"
      name         = "statement_timeout"
      value        = "1200000"
    },
    {
      apply_method = "pending-reboot"
      name         = "cron.database_name"
      value        = local.env
    },
    {
      apply_method = "pending-reboot"
      name         = "shared_preload_libraries"
      value        = "pg_stat_statements,pg_cron"
    }
  ]
}

# use the `db` module's output to write parameter to SSM parameter store:
resource "aws_ssm_parameter" "writer_endpoint" {
  name  = "/ab2d/${local.env}/core/nonsensitive/writer_endpoint"
  value = "${module.db.aurora_cluster.endpoint}:${module.db.aurora_cluster.port}"
  type  = "String"
}

```

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
| <a name="input_instance_class"></a> [instance\_class](#input\_instance\_class) | Aurora cluster instance class, restricted to RI instances | `string` | n/a | yes |
| <a name="input_maintenance_window"></a> [maintenance\_window](#input\_maintenance\_window) | Weekly time range during which system maintenance can occur in UTC, e.g. `wed:04:00-wed:04:30` | `string` | n/a | yes |
| <a name="input_password"></a> [password](#input\_password) | The database's primary/master credentials password | `string` | n/a | yes |
| <a name="input_platform"></a> [platform](#input\_platform) | Object that describes standardized platform values. | `any` | n/a | yes |
| <a name="input_username"></a> [username](#input\_username) | The database's primary/master credentials username | `string` | n/a | yes |
| <a name="input_aws_backup_tag"></a> [aws\_backup\_tag](#input\_aws\_backup\_tag) | Override for a standard, CDAP-managed backup tag for AWS Backups | `string` | `"4hr7_w90"` | no |
| <a name="input_backup_retention_period"></a> [backup\_retention\_period](#input\_backup\_retention\_period) | Days to retain backups for. | `number` | `1` | no |
| <a name="input_cluster_identifier"></a> [cluster\_identifier](#input\_cluster\_identifier) | Override for the aurora cluster identifier | `string` | `null` | no |
| <a name="input_cluster_instance_parameters"></a> [cluster\_instance\_parameters](#input\_cluster\_instance\_parameters) | A list of objects containing the values for apply\_method, name, and value that corresponds to the instance-level prameters. | <pre>list(object({<br/>    apply_method = string<br/>    name         = string<br/>    value        = any<br/>  }))</pre> | `[]` | no |
| <a name="input_cluster_parameters"></a> [cluster\_parameters](#input\_cluster\_parameters) | A list of objects containing the values for apply\_method, name, and value that corresponds to the cluster-level prameters. | <pre>list(object({<br/>    apply_method = string<br/>    name         = string<br/>    value        = any<br/>  }))</pre> | `[]` | no |
| <a name="input_deletion_protection"></a> [deletion\_protection](#input\_deletion\_protection) | If the DB cluster should have deletion protection enabled. | `bool` | `true` | no |
| <a name="input_engine_version"></a> [engine\_version](#input\_engine\_version) | Selected engine version for either RDS DB Instance or RDS Aurora DB Cluster. | `string` | `"16.8"` | no |
| <a name="input_instance_count"></a> [instance\_count](#input\_instance\_count) | Desired number of cluster instances | `number` | `1` | no |
| <a name="input_kms_key_override"></a> [kms\_key\_override](#input\_kms\_key\_override) | Override to the platform-managed KMS key | `string` | `null` | no |
| <a name="input_monitoring_interval"></a> [monitoring\_interval](#input\_monitoring\_interval) | The [monitoring\_interval](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/rds_cluster#monitoring_interval-1) in seconds determines the time between sampling enhanced monitoring metrics for the cluster. | `number` | `15` | no |
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
| [aws_db_parameter_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_parameter_group) | resource |
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
