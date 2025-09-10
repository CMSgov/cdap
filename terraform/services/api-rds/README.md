# OpenTofu for the AWS RDS configuration for APIs in target accounts

This OpenTofu code sets up the RDS for the APIs.

## Instructions

Pass in a backend file when running terraform init. Example:

```bash
tofu init -reconfigure -backend-config=../../backends/ab2d-dev.s3.tfbackend
tofu plan
```
