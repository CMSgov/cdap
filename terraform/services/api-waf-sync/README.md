# Terraform for api-waf-sync function and associated infra

This service sets up the infrastructure for the api-waf-sync lambda function in dev for BCDA/DPC.

## Manual deploy

Pass in a backend file when running terraform init. See variables.tf for variables to include. Example:

```bash
export TF_VAR_env=dev
terraform init -backend-config=../../backends/dpc-dev-gf.s3.tfbackend
terraform apply
```

## Automated deploy

This terraform is automatically applied on merge to main by the waf-sync-apply.yml workflow.
