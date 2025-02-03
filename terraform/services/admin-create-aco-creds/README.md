# Terraform for Admin ACO Deny function and associated infra

This service sets up the infrastructure for the Admin Create ACO Credentials lambda function in upper and lower environments for BCDA.

## Manual deploy

Pass in a backend file when running terraform init. See variables.tf for variables to include. Example:

```bash
terraform init -backend-config=../../backends/bcda-dev.s3.tfbackend
terraform apply
```

## Automated deploy

This terraform is automatically applied on merge to main by the admin-create-aco-creds-apply.yml workflow.
