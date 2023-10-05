# Connecting AWS account via OIDC
Using AWS console, in IAM, an identity provider was created using OpenID Connect.
A role was created (github-to-aws-oidc) using web identity and permissions added to the role to allow github action provision resources to aws

# When running workflow, you will be prompted to enter team, environment and action
Team (DPC, AB2D)
Environment (dev, east-impl, east-prod, sbx, test, prod )
Action (plan, apply)
