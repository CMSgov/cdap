## CMS CDAP-Managed Cross-Region Backup Plan

The default plans for AWS Backup managed by CMS Cloud do not suit our backup needs for Aurora databases because they:
* do not create cross-region backups,
* create more 4-hour backups than needed
* include cold storage transfer options that do not apply

CDAP has created this AWS Backup Plan for our Aurora Cluster.  


## Architecture

```
Primary Region (us-east-1)           Secondary Region (us-west-2)
┌────────────────────────────┐          ┌──────────────────────────┐
│ Primary Backup Vault       │          │ Secondary Backup Vault   │
│ ├─ 4hr1_d7_w35_m90 Backups │──────────│ ├─ Replicated 4hr x 6    │
│ └─ Retention as noted      │ Copy Job | └─ Retention 1 day       │
└────────────────────────────┘          └──────────────────────────┘
```

<!-- BEGIN_TF_DOCS -->
## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | n/a |
| <a name="provider_aws.secondary"></a> [aws.secondary](#provider\_aws.secondary) | n/a |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_standards"></a> [standards](#module\_standards) | github.com/CMSgov/cdap//terraform/modules/standards | 0bd3eeae6b03cc8883b7dbdee5f04deb33468260 |

## Resources

| Name | Type |
|------|------|
| [aws_backup_plan.aws_backup_plan](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/backup_plan) | resource |
| [aws_backup_selection.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/backup_selection) | resource |
| [aws_backup_vault.primary_backup_vault](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/backup_vault) | resource |
| [aws_backup_vault.secondary_backup_vault](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/backup_vault) | resource |
| [aws_backup_vault_lock_configuration.primary_vault_lock](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/backup_vault_lock_configuration) | resource |
| [aws_backup_vault_lock_configuration.secondary_vault_lock](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/backup_vault_lock_configuration) | resource |
| [aws_backup_vault_policy.primary_backup_vault_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/backup_vault_policy) | resource |
| [aws_backup_vault_policy.secondary_backup_vault_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/backup_vault_policy) | resource |
| [aws_kms_key_policy.primary_backup_key_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key_policy) | resource |
| [aws_kms_key_policy.secondary_backup_key_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key_policy) | resource |
| [aws_iam_policy_document.primary_backup_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.secondary_backup_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_kms_alias.primary_kms_alias](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/kms_alias) | data source |
| [aws_kms_alias.secondary_kms_alias](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/kms_alias) | data source |
| [aws_kms_key.primary_kms_key](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/kms_key) | data source |
| [aws_kms_key.secondary_kms_key](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/kms_key) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_env"></a> [env](#input\_env) | The application environment (dev, test, prod) | `string` | n/a | yes |
| <a name="input_vault_name"></a> [vault\_name](#input\_vault\_name) | Name of the primary backup vault | `string` | `"CMS-CDAP-MANAGED_VAULT"` | no |

## Outputs

No outputs.
<!-- END_TF_DOCS -->