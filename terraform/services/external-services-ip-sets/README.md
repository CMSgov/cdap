# OpenTofu for WAF IP sets for external services

This OpenTofu code sets up regional and cloudfront WAF IP sets for external services, including Zscaler, New Relic, etc. The IP ranges within these IP sets are not managed by this OpenTofu.

## Instructions

Pass in a backend file when running tofu init. Example:

```bash
tofu init -reconfigure -backend-config=../../backends/ab2d-dev.s3.tfbackend
tofu plan
```
