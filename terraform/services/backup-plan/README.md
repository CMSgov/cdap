## CMS CDAP-Managed Cross-Region Backup Plan

The default plans for AWS Backup managed by CMS Cloud do not suit our backup needs for Aurora databases because they:
* do not create cross-region backups,
* create more 4-hour backups than needed
* include cold storage transfer options that do not apply

CDAP has created this AWS Backup Plan for our Aurora Cluster.  


## Architecture

```
Primary Region (us-east-1)           Secondary Region (us-west-2)
┌─────────────────────────┐          ┌─────────────────────────┐
│ Primary Backup Vault    │          │ Secondary Backup Vault  │
│ ├─ Daily Backups        │──────────│ ├─ Replicated Backups   │
│ └─ 365d Retention       │ Copy Job | └─ 365d Retention       │
└─────────────────────────┘          └─────────────────────────┘
```
