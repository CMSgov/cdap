# Terraform for the AWS RDS configuration for APIs in target accounts

This terraform code sets up the RDS for the APIs.

## Instructions

Pass in a backend file when running terraform init. Example:

```bash
terraform init -reconfigure -backend-config=../../backends/ab2d-dev.s3.tfbackend
terraform plan
```

# Legacy and greenfield deployment

For greenfield deployment var.legacy = true which by default is set to true

For legacy deployment set Var.legacy to false
