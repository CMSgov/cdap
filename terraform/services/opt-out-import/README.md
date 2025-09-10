# OpenTofu for opt-out-import function and associated infra

This service sets up the infrastructure for the opt-out-import lambda function in upper and lower environments for all teams.

## Manual deploy

Pass in a backend file when running terraform init. See variables.tf for variables to include. Example:

```bash
tofu init -backend-config=../../backends/dpc-dev.s3.tfbackend
tofu apply
```

## Automated deploy

This OpenTofu is automatically applied on merge to main by the tf-opt-out-import.yml workflow.
