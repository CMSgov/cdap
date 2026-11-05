# OpenTofu for the GitHub Actions role in target accounts

This OpenTofu code sets up the role for GitHub Actions to assume in target accounts (prod and non-prod) to make application and infrastructure changes. These policies should be generated with principle of least privilege, specifying resources by naming convention as much as possible. Resources shared by multiple teams will require consistent naming conventions.

CDAP has a dedicated policy set to support account-level resource generation that the application repositories ToFu does not manage. 

## Instructions

Pass in a backend file when running tofu init. Example:

```bash
tofu init -reconfigure -backend-config=../../backends/ab2d-dev.s3.tfbackend
tofu plan
```
