output "kms_key_arns" {
  description = "Map of KMS key ARNs keyed by app-env"
  value = {
    for k, v in aws_kms_key.shares : k => v.arn
  }
}

output "kms_key_arns_by_app" {
  description = "KMS key ARNs grouped by app name, then by env"
  value = {
    for app in distinct([for v in local.kms_shares : v.app]) :
    app => {
      for k, v in local.kms_shares : v.env => aws_kms_key.shares[k].arn
      if v.app == app
    }
  }
}
