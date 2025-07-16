
# Terraform for KMS Key Service

This service provisions a **pair of AWS KMS Customer Managed Keys (CMKs)** — one in each of two different AWS accounts — to support secure encryption for application environments. A shared key model is used to reduce cost and simplify configuration across services.

## Purpose

Creates and manages standard KMS keys and aliases per environment (e.g., dev, test, prod) across primary and secondary AWS accounts using Terraform.

## Manual Deploy

To deploy manually, pass in a backend config file during `terraform init`. Example:

```bash
terraform init -backend-config=../../backends/ab2d-dev.s3.tfbackend
terraform plan
```
