# Terraform for opt-out-export function

This service sets up the infrastructure for the opt-out-export lambda function in upper and lower environments for all teams.

## Manual deploy

Pass in a backend file when running terraform init. See variables.tf for variables to include. Example:

```bash
export TF_VAR_app=ab2d
export TF_VAR_env=dev
terraform init -backend-config=../../backends/$TF_VAR_app-$TF_VAR_env-gf.s3.tfbackend
terraform apply
```

## Automated deploy

This terraform is automatically applied on merge to main by the tf-opt-out-export-cluster.yml workflow.
