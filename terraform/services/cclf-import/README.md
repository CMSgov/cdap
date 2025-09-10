# OpenTofu for cclf-import function and associated infra

This service sets up the infrastructure for the cclf-import lambda function in upper and lower environments for BCDA.

## Manual deploy

Pass in a backend file when running tofu init. See variables.tf for variables to include. Example:

```bash
tofu init -backend-config=../../backends/ab2d-dev.s3.tfbackend
tofu apply
```

## Automated deploy

This OpenTofu is automatically applied on merge to main by the cclf-import-apply.yml workflow.
