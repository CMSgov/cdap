# Terraform for GitHub Actions runners

This terraform builds infrastructure for GitHub Actions runners, relying on this module: https://github.com/philips-labs/terraform-aws-github-runner

See variables.tf for input variables, which include info for the corresponding GitHub App and the AMI for the runners.

This terraform outputs the `webhook_endpoint`, which must be updated in the GitHub App if it changes.

See [/terraform/README.md](/terraform/README.md) for instructions on initializing and applying terraform.
