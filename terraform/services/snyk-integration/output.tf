output "snyk_role_arns" {
  description = "The ARNs of the Snyk roles for each app"
  value = {
    for app in local.app : app => aws_iam_role.snyk[app].arn
  }
}
