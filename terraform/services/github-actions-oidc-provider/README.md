# OpenTofu for GitHub Actions OIDC provider

Run this in each account to create an OIDC identity provider for GitHub Actions. This allows us to assume roles in AWS accounts from GitHub-hosted runners.

    tofu init -reconfigure -backend-config=../../backends/ab2d-dev.s3.tfbackend
    tofu apply
