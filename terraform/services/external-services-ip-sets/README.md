# Terraform for WAF IP sets for external services

This terraform code sets up regional and cloudfront WAF IP sets for external services, including Zscaler, New Relic, etc. The IP ranges within these IP sets are not managed by this terraform.

## Instructions

Pass in a backend file when running terraform init. Example:

```bash
terraform init -reconfigure -backend-config=../../backends/ab2d-dev-gf.s3.tfbackend
terraform plan
```
