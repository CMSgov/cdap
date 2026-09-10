locals {
  # Read directly from the module in this same state -- no SSM round trip
  # needed here, since there's no state boundary to cross. (606, in its
  # own state, reads these same values back via SSM instead.)
  db_host               = local.tftesting_cluster_exists ? split(":", module.database[0].writer_endpoint)[0] : null
  breakglass_secret_arn = local.tftesting_cluster_exists ? module.database[0].breakglass_secret_arn : null
}

# Breakglass-authenticated, on purpose, and for this one step only:
# it creates our CI migration role and grants it access, so
# nothing downstream ever needs this credential again.
#
# The breakglass password is fetched by the script itself via the AWS CLI
# and never passed through ToFu.
#
# No "authorized" flag: if this runs from somewhere with no route into the
# VPC the psql call below times out and the apply fails,
# leaving this resource tainted. The next apply from CodeBuild (which has
# a real network path) retries it automatically.
resource "null_resource" "bootstrap_migrator_role" {
  count = local.tftesting_cluster_exists ? 1 : 0

  triggers = {
    bootstrap_sha = filesha256("${path.module}/bootstrap.sql")
  }

  provisioner "local-exec" {
    working_dir = path.module
    environment = {
      SECRET_ARN        = local.breakglass_secret_arn
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
}
