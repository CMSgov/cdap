# Terraform for opt-out-import lambda and associated infra

This service sets up the infrastructure for the opt-out-import lambda in upper and lower environments for all teams.

## Manual deploy

Pass in a backend file when running terraform init. See variables.tf for variables to include. Example:

```bash
terraform init -backend-config=../../backends/ab2d-dev.s3.tfbackend
terraform apply
```

## Automated deploy

This terraform is automatically applied on merge to main by the opt-out-import-apply.yml workflow.
