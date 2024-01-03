locals {
  release_tag = "v4.1.1"
}

module "lambdas" {
  source = "github.com/philips-labs/terraform-aws-github-runner//modules/download-lambda"
  lambdas = [
    {
      name = "webhook"
      tag  = local.release_tag
    },
    {
      name = "runners"
      tag  = local.release_tag
    },
    {
      name = "runner-binaries-syncer"
      tag  = local.release_tag
    }
  ]
}

output "files" {
  value = module.lambdas.files
}
