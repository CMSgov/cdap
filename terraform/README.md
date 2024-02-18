# Platform terraform

At the top level, terraform in this repo is organized into backends, modules, and services.

In **backends** we have terraform backend configuration files, as documented here: <https://developer.hashicorp.com/terraform/language/settings/backends/configuration#file>

In **modules** we have terraform wrapping generic resources, which may be referenced in **services** in this repo as well as in other repos. These modules manage standard configuration for AWS resources to avoid repetition and comply with CMS policies.

In **services** we have terraform split into functional units. For background on organizing terraform into *terraservices*, see this talk: <https://www.hashicorp.com/resources/evolving-infrastructure-terraform-opencredo>

## Version

Note that the terraform version is set in [.terraform-version](.terraform-version). If you use [tfenv](https://github.com/tfutils/tfenv) then the correct version of terraform will be installed and used automatically.
