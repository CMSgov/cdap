# OpenTofu for opt-out-export function

This service sets up the infrastructure for the opt-out-export lambda function in upper and lower environments for all teams.

## Manual deploy

Pass in a backend file when running terraform init. See variables.tf for variables to include. Example:

```bash
tofu init -backend-config=../../backends/dpc-dev.s3.tfbackend
tofu apply
```

## Automated deploy

This OpenTofu is automatically applied on merge to main by the tf-opt-out-export.yml workflow.
