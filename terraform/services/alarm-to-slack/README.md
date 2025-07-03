# Terraform for alarm-to-slack function and associated infra

This service sets up the infrastructure for the alarm-to-slack lambda function in upper and lower environments for DPC

## Manual deploy

Pass in a backend file when running terraform init. See variables.tf for variables to include. Example:

```bash
terraform init -backend-config=../../backends/dpc-dev-gf.s3.tfbackend
terraform apply
```

## Automated deploy

This terraform is automatically applied on merge to main by the tf-alarm-to-slack-apply.yml workflow.
