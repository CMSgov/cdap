# Terraform for GitHub Actions OIDC provider

Run this in each account to create an OIDC identity provider for GitHub Actions. This allows us to assume roles in AWS accounts from GitHub-hosted runners.

    terraform init -reconfigure -backend-config=../../backends/ab2d-dev-gf.s3.tfbackend
    terraform apply
