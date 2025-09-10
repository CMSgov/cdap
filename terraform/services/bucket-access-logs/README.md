# OpenTofu for bucket-access-logs in target accounts

This OpenTofu code manages an s3 bucket in each target account (prod and non-prod) for logging access to other S3 buckets. The tfstate is kept in bcda-test and bcda-prod buckets.

## Instructions

Pass in a backend file when running tofu init. Example:

```bash
tofu init -reconfigure -backend-config=../../backends/bcda-test.s3.tfbackend
tofu plan
```
