# CDAP Config Root Module

This root module is responsible for configuring the sops-enabled strategy for storing sensitive and nonsensitive configuration in AWS SSM Parameter Store.
The _parent environment_ specific configuration values are located in the `values` directory.

Usage:
```hcl
# declare the `db` module, defining the desired input variables
module "db" {
 source = "github.com/CMSgov/cdap//terraform/modules/aurora"

 backup_retention_period = module.platform.is_ephemeral_env ? 1 : 7
 deletion_protection     = !module.platform.is_ephemeral_env
 password                = module.platform.ssm.core.database_password.value
 username                = module.platform.ssm.core.database_user.value
 platform                = module.platform

}

# use the `db` module's output to write parameter to SSM parameter store:
resource "aws_ssm_parameter" "writer_endpoint" {
 name  = "/cdap/writer_endpoint"
 value = "${module.db.aurora_cluster.endpoint}:${module.db.aurora_cluster.port}"
type   = "String"
}
```


<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 5 |

## Providers

No providers.

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_platform"></a> [platform](#module\_platform) | github.com/CMSgov/cdap//terraform/modules/platform | ff2ef539fb06f2c98f0e3ce0c8f922bdacb96d66 |
| <a name="module_sops"></a> [sops](#module\_sops) | github.com/CMSgov/cdap//terraform/modules/sops | ff2ef539fb06f2c98f0e3ce0c8f922bdacb96d66 |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_region"></a> [region](#input\_region) | n/a | `string` | `"us-east-1"` | no |
| <a name="input_secondary_region"></a> [secondary\_region](#input\_secondary\_region) | n/a | `string` | `"us-west-2"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_edit"></a> [edit](#output\_edit) | n/a |
<!-- END_TF_DOCS -->
