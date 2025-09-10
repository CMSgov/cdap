# OpenTofu for Snyk role in target accounts

This OpenTofu code sets up the role for Snyk to assume in target accounts (prod and non-prod) to enable Snyk scanning integration.

## Instructions

Pass in a backend file when running tofu init. Example:

```bash
tofu init -reconfigure -backend-config=../../backends/ab2d-dev.s3.tfbackend
tofu plan
```
