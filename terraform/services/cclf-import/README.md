# Terraform for cclf-import function and associated infra

This service sets up the infrastructure for the cclf-import lambda function in upper and lower environments for BCDA.

## Manual deploy

Pass in a backend file when running terraform init. See variables.tf for variables to include. Example:

```bash
terraform init -backend-config=../../backends/ab2d-dev-gf.s3.tfbackend
terraform apply
```

## Automated deploy

This terraform is automatically applied on merge to main by the cclf-import-apply.yml workflow.
