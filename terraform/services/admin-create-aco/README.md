# Terraform for Admin Create ACO function and associated infra

This service sets up the infrastructure for the Admin Create ACO lambda function in upper and lower environments for BCDA.

## Manual deploy

Pass in a backend file when running terraform init. See variables.tf for variables to include. Example:

```bash
terraform init -backend-config=../../backends/bcda-dev-gf.s3.tfbackend
terraform apply
```

## Automated deploy

This terraform is automatically applied on merge to main by the admin-create-aco-apply.yml workflow.
