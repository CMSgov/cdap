terraform {
  backend "s3" {
    key = "github-actions-oidc-provider/terraform.tfstate"
  }
}

module "iam_github_oidc_provider" {
  source = "terraform-aws-modules/iam/aws//modules/iam-github-oidc-provider"

  tags = {
    business  = "oeda"
    code      = "https://github.com/CMSgov/ab2d-bcda-dpc-platform/tree/main/terraform/services/github-actions-oidc-provider"
    component = "github-actions"
    terraform = true
  }
}
