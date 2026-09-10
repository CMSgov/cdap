data "aws_ssm_parameter" "writer_endpoint" {
  name = "/${local.aurora_app_name}/${module.platform.env}/tftesting-database/nonsensitive/writer-endpoint"
}

data "aws_ssm_parameter" "breakglass_secret_arn" {
  name = "/${local.aurora_app_name}/${module.platform.env}/tftesting-database/nonsensitive/breakglass-user-secret-arn"
}

locals {
  db_host = split(":", data.aws_ssm_parameter.writer_endpoint.value)[0]
}

# Breakglass-authenticated, for only this step: its
# only job is creating tftesting_migrator and tftesting_human and
# granting rds_iam to both, so nothing downstream ever needs this
# credential again.
#
resource "null_resource" "bootstrap_roles" {
  triggers = {
    bootstrap_sha = filesha256("${path.module}/bootstrap.sql")
  }

  provisioner "local-exec" {
    working_dir = path.module
    environment = {
      SECRET_ARN        = data.aws_ssm_parameter.breakglass_secret_arn.value
      PGHOST            = local.db_host
      PGPORT            = "5432"
      PGDATABASE        = "postgres"
      PGSSLMODE         = "require"
      PGCONNECT_TIMEOUT = "10"
    }
    command     = <<-EOF
      set -euo pipefail
      SECRET_JSON=$(aws secretsmanager get-secret-value --secret-id "$SECRET_ARN" --query SecretString --output text)
      export PGUSER=$(echo "$SECRET_JSON" | jq -r .username)
      export PGPASSWORD=$(echo "$SECRET_JSON" | jq -r .password)
      psql -v ON_ERROR_STOP=1 -f bootstrap.sql
      unset PGPASSWORD SECRET_JSON
    EOF
    interpreter = ["/bin/bash", "-c"]
  }

  depends_on = [
    aws_vpc_security_group_ingress_rule.codebuild,
    aws_vpc_security_group_egress_rule.codebuild,
  ]
}
