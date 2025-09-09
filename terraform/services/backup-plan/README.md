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
│ ├─ 4hr1CA_d7_w35_m90 Backup│──────────│ ├─ Replicated 4hr x 6    │
│ └─ Retention as noted      │ Copy Job | └─ Retention 1 day       │
└────────────────────────────┘          └──────────────────────────┘
```

<!-- BEGIN_TF_DOCS -->
## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 5.100.0 |
| <a name="provider_aws.secondary"></a> [aws.secondary](#provider\_aws.secondary) | 5.100.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_standards"></a> [standards](#module\_standards) | github.com/CMSgov/cdap//terraform/modules/standards | 0bd3eeae6b03cc8883b7dbdee5f04deb33468260 |

## Resources

| Name | Type |
|------|------|
| [aws_backup_plan.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/backup_plan) | resource |
| [aws_backup_selection.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/backup_selection) | resource |
| [aws_backup_vault.primary](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/backup_vault) | resource |
| [aws_backup_vault.secondary](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/backup_vault) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_env"></a> [env](#input\_env) | The application environment (dev, test, prod) | `string` | n/a | yes |

## Outputs

No outputs.
<!-- END_TF_DOCS -->