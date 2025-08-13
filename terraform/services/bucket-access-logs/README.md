# Terraform for bucket-access-logs in target accounts

This terraform code manages an s3 bucket in each target account (prod and non-prod) for logging access to other S3 buckets. The tfstate is kept in bcda-test and bcda-prod buckets.

## Instructions

Pass in a backend file when running terraform init. Example:

```bash
terraform init -reconfigure -backend-config=../../backends/bcda-test-gf.s3.tfbackend
terraform plan
```
