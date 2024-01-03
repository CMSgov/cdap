# Wrapper to download lambdas for github runners

Use this module to download Lambda zip files from the GitHub release for terraform-aws-github-runner. These files are checked into the repo, so this only needs to be run when the zip files need to be updated.

This module is adapted from [the lambdas-download example](https://github.com/philips-labs/terraform-aws-github-runner/tree/d0e89608f52ff0db4abe204af6718a73e780ea98/examples/lambdas-download). To update the zip files, apply terraform in this directory:

    terraform init
    terraform apply

Note that because this terraform is only downloading files and not touching AWS, the state is kept in a local tfstate file.
