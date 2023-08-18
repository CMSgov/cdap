# Platform terraform

Terraform in this repo is organized into backends, modules, and services.

In **backends** we have terraform backend configuration files, as documented here: <https://developer.hashicorp.com/terraform/language/settings/backends/configuration#file>

In **modules** we have terraform in shared modules, which may be referenced in **services** in this repo as well as in other repos.

In **services** we have terraform split into functional units. For background on organizing terraform into *terraservices*, see this talk: <https://www.hashicorp.com/resources/evolving-infrastructure-terraform-opencredo>

Within each service, the relevant backend configuration must be referenced to initialize before applying. For example, to apply terraform for our GitHub Actions infrastructure in the BCDA account, you would run these commands in the [services/github-actions](services/github-actions) directory:

    terraform init -reconfigure -backend-config=../../backends/bcda.s3.tfbackend
    terraform apply

## Version

Note that the terraform version is set in [.terraform-version](.terraform-version). If you use [tfenv](https://github.com/tfutils/tfenv) then the correct version of terraform will be installed and used automatically.
