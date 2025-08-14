# Terraform for the GitHub Actions role in target accounts

This terraform code sets up the role for GitHub Actions to assume in target accounts (prod and non-prod) to make application and infrastructure changes.

## Instructions

Pass in a backend file when running terraform init. Example:

```bash
terraform init -reconfigure -backend-config=../../backends/ab2d-dev.s3.tfbackend
terraform plan
```
