# Terraform for security groups

This terraform service creates and manages shared security groups. Currently included:

- access from public and private Zscaler (ingress CIDRs managed outside of terraform)
- access to the internet (http and https)
- access from the CDAP management VPC

Note that Zscaler and management security groups are created without rules. Those are added and kept in sync by workflows that parse CIDR files in the private repo.

## Instructions

Pass in a backend file when running terraform init. Example:

```bash
terraform init -reconfigure -backend-config=../../backends/ab2d-dev.s3.tfbackend
terraform plan
```
