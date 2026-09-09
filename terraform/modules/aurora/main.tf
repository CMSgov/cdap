resource "aws_db_subnet_group" "this" {
  description = "${local.service_prefix} database subnet group"
  name        = coalesce(var.subnet_group_override, local.service_prefix)
  subnet_ids  = keys(var.platform.private_subnets)
}

resource "aws_security_group" "this" {
  description            = "${local.service_prefix} database security group"
  name                   = local.security_group_name
  revoke_rules_on_delete = false
  tags = {
    Name = local.security_group_name
  }
  vpc_id = var.platform.vpc_id

  lifecycle {
    ignore_changes = [
      description
    ]
  }
}

resource "aws_ssm_parameter" "db_security_group_id" {
  name  = "/${var.platform.app}/${var.platform.env}/aurora/nonsensitive/db-security-group-id"
  value = aws_security_group.this.id
  type  = "String"

  tags = {
    Name = "/${var.platform.app}/${var.platform.env}/aurora/nonsensitive/db-security-group-id"
  }
}

resource "aws_vpc_security_group_egress_rule" "this" {
  cidr_ipv4         = "0.0.0.0/0"
  description       = "Allow all egress"
  ip_protocol       = "-1"
  security_group_id = aws_security_group.this.id
}

resource "aws_rds_cluster_parameter_group" "this" {
  name        = "${local.service_prefix}-cluster"
  family      = local.aurora_family
  description = "Aurora cluster parameter group for ${local.service_prefix}"

  dynamic "parameter" {
    for_each = toset(concat(local.default_cluster_parameters, var.cluster_parameters))

    content {
      apply_method = parameter.value.apply_method
      name         = parameter.value.name
      value        = parameter.value.value
    }
  }
}

resource "aws_db_parameter_group" "this" {
  name        = "${local.service_prefix}-instance"
  family      = local.aurora_family
  description = "Aurora DB instance parameter group for ${local.service_prefix}"

  dynamic "parameter" {
    for_each = toset(var.cluster_instance_parameters)

    content {
      apply_method = parameter.value.apply_method
      name         = parameter.value.name
      value        = parameter.value.value
    }
  }

  lifecycle {
    ignore_changes = [
      description
    ]
  }
}

data "aws_rds_engine_version" "this" {
  engine       = "aurora-postgresql"
  version      = var.engine_version
  default_only = true
  latest       = true
}

resource "aws_rds_cluster" "this" {
  cluster_identifier   = coalesce(var.cluster_identifier, local.service_prefix)
  engine               = local.aurora_engine
  engine_version       = data.aws_rds_engine_version.this.version
  master_username      = var.username
  snapshot_identifier  = var.snapshot_identifier
  db_subnet_group_name = aws_db_subnet_group.this.name
  storage_type         = var.storage_type
  storage_encrypted    = true
  kms_key_id           = coalesce(var.kms_key_override, var.platform.kms_alias_primary.target_key_arn)

  # --- Master credential ---
  # Teams that opt in to manage_master_user_password get an RDS-managed secret in Secrets
  # Manager instead, with rotation available (but not enabled) via
  # master_password_rotation_days below.
  master_password               = var.manage_master_user_password ? null : var.password
  manage_master_user_password   = var.manage_master_user_password
  master_user_secret_kms_key_id = var.manage_master_user_password ? coalesce(var.kms_key_override, var.platform.kms_alias_primary.target_key_arn) : null

  backup_retention_period         = var.backup_retention_period
  preferred_backup_window         = var.backup_window
  preferred_maintenance_window    = var.maintenance_window
  apply_immediately               = false
  skip_final_snapshot             = true
  deletion_protection             = var.deletion_protection
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.this.name

  # --- IAM database authentication ---
  # This only turns on the capability. A given Postgres
  # role only becomes IAM-authenticable once a consuming terraservice grants
  # it `rds_iam` in the database and attaches its own IAM policy scoped to
  # that dbuser -- built from the cluster_resource_id this module publishes
  # via SSM below. This module intentionally does not create IAM policies
  # or grants itself, so that access is owned by, and torn down with, the
  # terraservice that needed it.
  iam_database_authentication_enabled = var.enable_iam_database_authentication

  copy_tags_to_snapshot           = true
  enabled_cloudwatch_logs_exports = ["postgresql"]

  vpc_security_group_ids = flatten([
    aws_security_group.this.id,
    var.platform.security_groups.cmscloud-security-tools.id,
    var.platform.security_groups.remote-management.id,
    var.platform.security_groups.zscaler-private.id,
    var.vpc_security_group_ids
  ])

  tags = {
    AWS_Backup = var.aws_backup_tag
  }

  # Along with the below commentary from @malessi on the support for monitoring-related settings,
  # this is largely for support of novel clusters (e.g. ephemeral clusters) and for clusters that take advantage
  # of Application Autoscaling. Note: Application Autoscaling is not yet supported in this module.
  provisioner "local-exec" {
    environment = {
      DB_CLUSTER_ID                    = self.cluster_identifier
      KMS_KEY_ID                       = self.kms_key_id
      ENHANCED_MONITORING_INTERVAL     = var.monitoring_interval
      ENHANCED_MONITORING_IAM_ROLE_ARN = var.monitoring_role_arn
    }
    command     = <<-EOF
    aws rds modify-db-cluster --db-cluster-identifier "$DB_CLUSTER_ID" \
      --performance-insights-kms-key-id "$KMS_KEY_ID" \
      --enable-performance-insights \
      --monitoring-interval "$ENHANCED_MONITORING_INTERVAL" \
      --monitoring-role-arn "$ENHANCED_MONITORING_IAM_ROLE_ARN" 1>/dev/null &&
      echo "Performance Insights and Enhanced Monitoring enabled for $DB_CLUSTER_ID"
    EOF
    interpreter = ["/bin/bash", "-c"]
  }

  # Ignore all changes to these properties as the above local-exec manages them.
  # Per @malessi, BFD-4145, et al, support for these configuration settings is
  # incomplete in the Terraform Provider for AWS
  lifecycle {
    ignore_changes = [
      monitoring_interval,
      monitoring_role_arn,
      performance_insights_enabled,
      performance_insights_kms_key_id,
      performance_insights_retention_period,
    ]
  }
}

# Rotation is opt-in and off by default (master_password_rotation_days = 0).
# Teams that want automatic rotation of the RDS-managed master secret can
# turn it on without any other change to this module.
resource "aws_secretsmanager_secret_rotation" "master_password" {
  count     = var.manage_master_user_password && var.master_password_rotation_days > 0 ? 1 : 0
  secret_id = aws_rds_cluster.this.master_user_secret[0].secret_arn

  rotation_rules {
    automatically_after_days = var.master_password_rotation_days
  }
}

resource "aws_rds_cluster_instance" "this" {
  count = var.instance_count

  identifier                 = "${coalesce(var.cluster_identifier, local.service_prefix)}-${count.index}"
  cluster_identifier         = aws_rds_cluster.this.id
  engine                     = aws_rds_cluster.this.engine
  engine_version             = aws_rds_cluster.this.engine_version
  db_subnet_group_name       = aws_db_subnet_group.this.name
  instance_class             = var.instance_class
  publicly_accessible        = false
  apply_immediately          = true
  auto_minor_version_upgrade = true
  db_parameter_group_name    = aws_db_parameter_group.this.name
  tags = {
    Name = "${local.service_prefix}-${count.index}"
  }

  lifecycle {
    ignore_changes = [
      monitoring_interval,
      monitoring_role_arn,
      performance_insights_enabled,
      performance_insights_kms_key_id,
      performance_insights_retention_period,
    ]
  }
}

resource "aws_ssm_parameter" "writer_endpoint" {
  name  = "/${var.platform.app}/${var.platform.env}/aurora/nonsensitive/writer-endpoint"
  value = "${aws_rds_cluster.this.endpoint}:${aws_rds_cluster.this.port}"
  type  = "String"
}

resource "aws_ssm_parameter" "reader_endpoint" {
  name  = "/${var.platform.app}/${var.platform.env}/aurora/nonsensitive/reader-endpoint"
  value = "${aws_rds_cluster.this.reader_endpoint}:${aws_rds_cluster.this.port}"
  type  = "String"
}

# Published so consuming terraservices (e.g. 30-my-lambda/iam.tf) can build
# their own rds-db:connect policy, scoped to their own dbuser, without this
# module needing to know which roles or users exist. This is what makes
# per-service IAM auth adoption possible without enforcing it on anyone.
resource "aws_ssm_parameter" "db_cluster_resource_id" {
  name  = "/${var.platform.app}/${var.platform.env}/aurora/nonsensitive/db-cluster-resource-id"
  value = aws_rds_cluster.this.cluster_resource_id
  type  = "String"

  tags = {
    Name = "/${var.platform.app}/${var.platform.env}/aurora/nonsensitive/db-cluster-resource-id"
  }
}

# The ARN itself isn't sensitive (it doesn't contain secret material), so
# it's published the same way as the other identifiers above.
resource "aws_ssm_parameter" "master_user_secret_arn" {
  count = var.manage_master_user_password ? 1 : 0

  name  = "/${var.platform.app}/${var.platform.env}/aurora/nonsensitive/master-user-secret-arn"
  value = aws_rds_cluster.this.master_user_secret[0].secret_arn
  type  = "String"

  tags = {
    Name = "/${var.platform.app}/${var.platform.env}/aurora/nonsensitive/master-user-secret-arn"
  }
}
