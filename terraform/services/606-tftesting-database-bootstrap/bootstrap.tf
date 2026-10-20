locals {
  tftesting_config         = yamldecode(file("${path.module}/config/default.yml"))["tftesting"]
  tftesting_state          = local.tftesting_config.state
  tftesting_cluster_exists = contains(["idle", "running"], local.tftesting_state)

  # bootstrap needs an actual live instance to connect to, not just a
  # cluster shell with zero instances
  tftesting_bootstrap_ready = local.tftesting_state == "running"
}

data "aws_ssm_parameter" "writer_endpoint" {
  count = local.tftesting_cluster_exists ? 1 : 0
  name  = "/${local.aurora_app_name}/${module.platform.env}/tftesting-database/nonsensitive/writer-endpoint"
}

data "aws_ssm_parameter" "breakglass_secret_arn" {
  count = local.tftesting_cluster_exists ? 1 : 0
  name  = "/${local.aurora_app_name}/${module.platform.env}/tftesting-database/nonsensitive/breakglass-user-secret-arn"
}

locals {
  db_host = local.tftesting_cluster_exists ? split(":", data.aws_ssm_parameter.writer_endpoint[0].value)[0] : null
}

resource "null_resource" "bootstrap_roles" {
  count = local.tftesting_bootstrap_ready ? 1 : 0

  triggers = {
    bootstrap_sha = filesha256("${path.module}/bootstrap.sql")
  }

  provisioner "local-exec" {
    working_dir = path.module
    environment = {
      SECRET_ARN        = data.aws_ssm_parameter.breakglass_secret_arn[0].value
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
