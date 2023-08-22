# Wrapper to download lambdas for github runners

Download Lambda zip files from the GitHub release for terraform-aws-github-runner. Copied from [the lambdas-download example](https://github.com/philips-labs/terraform-aws-github-runner/tree/d0e89608f52ff0db4abe204af6718a73e780ea98/examples/lambdas-download). Before applying terraform in the parent "github-actions" directory, apply terraform in this directory with the following commands, specifying the module version:

    terraform init
    terraform apply -var=module_version=<VERSION>
