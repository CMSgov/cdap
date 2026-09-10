locals {
  cdap_env = contains(["dev", "test"], local.parent_env) ? "test" : "prod"

  access_logs_bucket = {
    "dev"     = "bucket-access-logs-20250409172631068600000001"
    "test"    = "bucket-access-logs-20250409172631068600000001"
    "sandbox" = "bucket-access-logs-20250411172631068600000001"
    "prod"    = "bucket-access-logs-20250411172631068600000001"
  }
}

data "aws_iam_policy" "permissions_boundary" {
  name = "ct-ado-poweruser-permissions-boundary-policy"
}

# assumes us-east-1 --
data "aws_vpc" "cdap" {
  filter {
    name   = "tag:Name"
    values = ["cdap-east-${local.cdap_env}"]
  }
}

data "aws_nat_gateways" "cdap" {
  vpc_id = data.aws_vpc.cdap.id
  filter {
    name   = "state"
    values = ["available"]
  }
}

data "aws_nat_gateway" "cdap" {
  for_each = toset(data.aws_nat_gateways.cdap.ids)
  id       = each.value
}

data "aws_s3_bucket" "access_logs" {
  bucket = local.access_logs_bucket[local.parent_env]
}

data "aws_s3_bucket" "logs_to_splunk" {
  bucket = "cms-cloud-${data.aws_caller_identity.this.account_id}-${data.aws_region.primary.region}"
}
