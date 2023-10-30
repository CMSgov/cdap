# Terraform for GitHub Actions deploy roles in target accounts

This terraform code sets up roles for GitHub Actions runners to assume in target accounts (prod and non-prod) to deploy application and infrastructure changes.

## Instructions

Pass in a backend file when running terraform init. Example:

```bash
terraform init -backend-config=../../../backends/ab2d-dev.s3.tfbackend
terraform plan
terraform apply
```
