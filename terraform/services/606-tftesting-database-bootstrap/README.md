## Human database access (optional, off by default)

When `enable_human_database_access = true`, this terraservice creates a
dedicated role, `${aurora_service_name}-human-db-access`, which can authenticate
to Postgres as `tftesting_human` via IAM database auth. By default, only
`ct-ado-bcda-application-admin` is allowed to assume it.

**Accountability note:** Postgres itself only ever logs `tftesting_human`
-- it has no idea which person connected. Real accountability lives in
CloudTrail instead: your federated session into
`ct-ado-bcda-application-admin` is already named after your EUA, and if
you carry that forward as the `--role-session-name` when you assume
`human-db-access` below, every `AssumeRole` and `GenerateDbAuthToken` call
in CloudTrail is traceable back to you specifically, even though the
database connection itself looks generic. Skipping this step doesn't
break anything technically, but it does throw away the one place this
path is actually auditable.

**1. Assume the role, using your own EUA as the session name:**

```bash
aws sts assume-role \
  --role-arn arn:aws:iam::<account-id>:role/delegatedadmin/developer/<aurora_service_name>-human-db-access \
  --role-session-name <your-eua>

  <!-- BEGIN_TF_DOCS -->
<!--WARNING: GENERATED CONTENT with terraform-docs, e.g.
     'terraform-docs --config "$(git rev-parse --show-toplevel)/.terraform-docs.yml" .'
     Manually updating sections between TF_DOCS tags may be overwritten.
     See https://terraform-docs.io/user-guide/configuration/ for more information.
-->
## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | ~>6.0 |
| <a name="provider_null"></a> [null](#provider\_null) | n/a |

<!--WARNING: GENERATED CONTENT with terraform-docs, e.g.
     'terraform-docs --config "$(git rev-parse --show-toplevel)/.terraform-docs.yml" .'
     Manually updating sections between TF_DOCS tags may be overwritten.
     See https://terraform-docs.io/user-guide/configuration/ for more information.
-->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~>6.0 |

<!--WARNING: GENERATED CONTENT with terraform-docs, e.g.
     'terraform-docs --config "$(git rev-parse --show-toplevel)/.terraform-docs.yml" .'
     Manually updating sections between TF_DOCS tags may be overwritten.
     See https://terraform-docs.io/user-guide/configuration/ for more information.
-->
## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_codebuild_security_group_id"></a> [codebuild\_security\_group\_id](#input\_codebuild\_security\_group\_id) | Security group attached to your CodeBuild-hosted GitHub Actions runners, granted a network path to the cluster on 5432. | `string` | n/a | yes |
| <a name="input_platform"></a> [platform](#input\_platform) | Object that describes standardized platform values. | `any` | n/a | yes |
| <a name="input_human_iam_principal_arns"></a> [human\_iam\_principal\_arns](#input\_human\_iam\_principal\_arns) | IAM role/user ARNs granted rds-db:connect as tftesting\_human, for<br/>direct human access to the cluster via a Postgres client, over<br/>Zscaler Private Access (already attached directly to the cluster by<br/>the aurora module).<br/><br/>Optional and mostly performative: most developers' existing<br/>admin/broad AWS role can likely already authenticate this way without<br/>any grant from this module. Populating this only matters if you want<br/>someone to assume a distinct, narrowly-scoped role for this purpose.<br/> Empty by default. | `list(string)` | `[]` | no |
| <a name="input_migrator_iam_principal_arns"></a> [migrator\_iam\_principal\_arns](#input\_migrator\_iam\_principal\_arns) | Additional IAM role/user ARNs granted rds-db:connect as<br/>tftesting\_migrator, for hand-testing migrations from a bastion or SSM<br/>session inside the VPC. Almost never needed in practice: your<br/>existing admin/developer AWS role likely already has broad enough<br/>permissions (e.g. rds-db:* or similar) to authenticate this way<br/>without any grant from this module. This exists mainly to demonstrate<br/>the scoped-access pattern for teams whose roles are narrower. Empty<br/>by default. | `list(string)` | `[]` | no |

<!--WARNING: GENERATED CONTENT with terraform-docs, e.g.
     'terraform-docs --config "$(git rev-parse --show-toplevel)/.terraform-docs.yml" .'
     Manually updating sections between TF_DOCS tags may be overwritten.
     See https://terraform-docs.io/user-guide/configuration/ for more information.
-->
## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_platform"></a> [platform](#module\_platform) | ../../modules/platform | n/a |

<!--WARNING: GENERATED CONTENT with terraform-docs, e.g.
     'terraform-docs --config "$(git rev-parse --show-toplevel)/.terraform-docs.yml" .'
     Manually updating sections between TF_DOCS tags may be overwritten.
     See https://terraform-docs.io/user-guide/configuration/ for more information.
-->
## Resources

| Name | Type |
|------|------|
| [aws_iam_policy.db_connect_human](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.db_connect_migrator](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role_policy_attachment.db_connect_human](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.db_connect_migrator](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.db_connect_migrator_ci](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_user_policy_attachment.db_connect_human](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_user_policy_attachment) | resource |
| [aws_iam_user_policy_attachment.db_connect_migrator](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_user_policy_attachment) | resource |
| [aws_vpc_security_group_egress_rule.codebuild](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.codebuild](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [null_resource.bootstrap_migrator_role](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.db_connect_human](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.db_connect_migrator](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_role.ci](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_role) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [aws_ssm_parameter.cluster_resource_id](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |
| [aws_ssm_parameter.codebuild_security_group_id](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |

<!--WARNING: GENERATED CONTENT with terraform-docs, e.g.
     'terraform-docs --config "$(git rev-parse --show-toplevel)/.terraform-docs.yml" .'
     Manually updating sections between TF_DOCS tags may be overwritten.
     See https://terraform-docs.io/user-guide/configuration/ for more information.
-->
## Outputs

No outputs.
<!-- END_TF_DOCS -->