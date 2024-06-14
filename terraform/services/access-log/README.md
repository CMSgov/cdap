# Terraform for access-log in target accounts

This terraform code sets up access-log s3 buckets in target accounts (prod and non-prod) to enable access-log S3 buckets.

## Instructions

Pass in a backend file when running terraform init. Example:

```bash
terraform init -reconfigure -backend-config=../../backends/ab2d-dev.s3.tfbackend
terraform plan
```
