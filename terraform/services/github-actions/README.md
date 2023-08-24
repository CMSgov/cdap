# Terraform for GitHub Actions runners

This terraform builds infrastructure for GitHub Actions runners, relying on this module: https://github.com/philips-labs/terraform-aws-github-runner

This terraform outputs the `webhook_endpoint`, which must be updated in the GitHub App if it changes.

See variables.tf for input variables, which include info for the corresponding GitHub App and the AMI for the runners. Before applying this terraform, the lambda zip files must also be downloaded by applying terraform in the "lambdas-download" child directory.

The terraform for this service is only applied to the "management" environment. Reference the bcda backend when initializing:

    terraform init -reconfigure -backend-config=../../backends/bcda.s3.tfbackend
    terraform apply
