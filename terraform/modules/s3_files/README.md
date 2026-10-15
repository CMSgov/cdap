# Terraform module for Amazon S3 Files resources

This module provisions an **Amazon S3 Files** file system on top of an existing Amazon S3 bucket, along with VPC mount targets and an access point suitable for mounting to AWS Lambda functions or containerized workloads (ECS/EKS).

## Architecture

```text
+-----------------------------------------------------------------+
|                 AWS Lambda / ECS Compute (VPC)                  |
+-----------------------------------------------------------------+
                                 |
                                 | NFS (TCP port 2049)
                                 v
+-----------------------------------------------------------------+
|   Mount Targets (aws_s3files_mount_target) in Private Subnets   |
+-----------------------------------------------------------------+
                                 |
                                 v
+-----------------------------------------------------------------+
|             Access Point (aws_s3files_access_point)             |
+-----------------------------------------------------------------+
                                 |
                                 v
+-----------------------------------------------------------------+
|              File System (aws_s3files_file_system)              |
+-----------------------------------------------------------------+
                                 |
                                 | Direct Streaming
                                 v
+-----------------------------------------------------------------+
|                    Backing Amazon S3 Bucket                     |
+-----------------------------------------------------------------+
```

## Features

- Mounts an S3 bucket via NFS without requiring preliminary file downloads or local disk buffering.
- Automatically resolves private subnets using the shared CDAP `subnets` module and provisions mount targets across all availability zones.
- Creates a dedicated security group for mount targets and manages NFS (TCP 2049) ingress rules from allowed client security groups.
- Defaults to read-only (`ro`) operations to enforce least privilege.
- Uses delegated admin IAM role paths (`/delegatedadmin/developer/`).

## Usage Example

```hcl
module "my_s3_files" {
  source = "github.com/CMSgov/cdap//terraform/modules/s3_files?ref=<TAG>"

  platform   = module.platform
  name       = "attribution-import-files"
  bucket_arn = module.my_bucket.arn
  read_only  = true
}

module "my_lambda" {
  source = "github.com/CMSgov/cdap//terraform/modules/function?ref=<TAG>"

  app         = "bcda"
  env         = "dev"
  name        = "my-lambda"
  ...
  file_system_config = {
    arn              = module.my_s3_files.access_point_arn
    local_mount_path = "/mnt/data"
  }
}

# Standalone security group rules connecting Lambda and S3 Files:
# 1. Allow NFS ingress to S3 Files mount targets from Lambda
resource "aws_vpc_security_group_ingress_rule" "s3_files_from_lambda" {
  security_group_id            = module.my_s3_files.security_group_id
  referenced_security_group_id = module.my_lambda.security_group_id
  ip_protocol                  = "tcp"
  from_port                    = 2049
  to_port                      = 2049
  description                  = "Allow NFS ingress from Lambda to S3 Files mount targets"
}

# 2. Allow NFS egress from Lambda to S3 Files mount targets
# (Required: the Lambda module default security group only allows outbound HTTPS/443)
resource "aws_vpc_security_group_egress_rule" "lambda_to_s3_files" {
  security_group_id            = module.my_lambda.security_group_id
  referenced_security_group_id = module.my_s3_files.security_group_id
  ip_protocol                  = "tcp"
  from_port                    = 2049
  to_port                      = 2049
  description                  = "Allow NFS egress from Lambda to S3 Files mount targets"
}
```

> [!NOTE]
> **Security Group Ordering & Module Dependencies:**
> When integrating with `modules/function`, avoid passing `module.my_lambda.security_group_id` into `allowed_security_group_ids` directly, as referencing module outputs back and forth creates a Terraform module dependency cycle. Use standalone ingress and egress rules as shown above. `allowed_security_group_ids` can be used when client security groups are provisioned independently prior to this module.


<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.40.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 6.40.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [aws_iam_role.s3files](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.s3files](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_s3files_access_point.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3files_access_point) | resource |
| [aws_s3files_file_system.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3files_file_system) | resource |
| [aws_s3files_mount_target.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3files_mount_target) | resource |
| [aws_security_group.mount_targets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_vpc_security_group_ingress_rule.nfs_from_allowed_sgs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_iam_policy_document.s3files_assume_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.s3files_bucket_access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_allowed_security_group_ids"></a> [allowed\_security\_group\_ids](#input\_allowed\_security\_group\_ids) | List of security group IDs permitted to mount the file system over NFS (TCP port 2049). Use this when client security groups are known upfront. When connecting to modules that consume this module's outputs (e.g. modules/function), define standalone rules in the caller to avoid dependency cycles. | `list(string)` | `[]` | no |
| <a name="input_bucket_arn"></a> [bucket\_arn](#input\_bucket\_arn) | Target S3 bucket ARN to mount | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Identifier suffix for the S3 Files resources (e.g. 'attribution-import-files') | `string` | n/a | yes |
| <a name="input_platform"></a> [platform](#input\_platform) | Object representing the CDAP platform module. | <pre>object({<br/>    app               = string<br/>    env               = string<br/>    kms_alias_primary = object({ target_key_arn = string })<br/>    vpc_id            = string<br/>    private_subnets   = map(object({ id = string }))<br/>  })</pre> | n/a | yes |
| <a name="input_read_only"></a> [read\_only](#input\_read\_only) | Whether the file system access should enforce read-only operations. Defaults to true. | `bool` | `true` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_access_point_arn"></a> [access\_point\_arn](#output\_access\_point\_arn) | ARN of the S3 Files access point (pass this to Lambda file\_system\_config.arn) |
| <a name="output_access_point_id"></a> [access\_point\_id](#output\_access\_point\_id) | ID of the S3 Files access point |
| <a name="output_file_system_arn"></a> [file\_system\_arn](#output\_file\_system\_arn) | ARN of the S3 Files file system |
| <a name="output_file_system_id"></a> [file\_system\_id](#output\_file\_system\_id) | ID of the S3 Files file system |
| <a name="output_security_group_id"></a> [security\_group\_id](#output\_security\_group\_id) | ID of the security group attached to the mount targets (use to wire NFS ingress and egress rules in caller service) |
| <a name="output_service_role_arn"></a> [service\_role\_arn](#output\_service\_role\_arn) | ARN of the IAM role used by S3 Files to access the backing S3 bucket |
<!-- END_TF_DOCS -->
