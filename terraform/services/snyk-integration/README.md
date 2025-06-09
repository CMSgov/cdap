# Terraform for Snyk role in target accounts

This terraform code sets up the role for Snyk to assume in target accounts (prod and non-prod) to enable Snyk scanning integration.

## Instructions

Pass in a backend file when running terraform init. Example:

```bash
terraform init -reconfigure -backend-config=../../backends/ab2d-dev.s3.tfbackend
terraform plan  -var='app=["ab2d"]'
```
