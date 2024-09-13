# Terraform for sync-waf function and associated infra

This service sets up the infrastructure for the sync-waf lambda function in dev for dpc.

## Manual deploy

Pass in a backend file when running terraform init. See variables.tf for variables to include. Example:

```bash
export TF_VAR_env=dev
terraform init -backend-config=../../backends/dpc-dev.s3.tfbackend
terraform apply
```

## Automated deploy

TBD
