locals {
  full_name  = "${var.app}-${var.env}-cclf-import"
  bfd_env    = var.env == "prod" ? "prod" : "test"
  db_sg_name = "${var.app}-${var.env}-db"
  memory_size = {
    bcda = 2048
  }
  extra_kms_key_arns = var.app == "bcda" ? [data.aws_kms_alias.bcda_app_config_kms_key[0].target_key_arn] : []
}

data "aws_kms_alias" "bcda_app_config_kms_key" {
  count = var.app == "bcda" ? 1 : 0
  name  = "alias/bcda-${var.env}-app-config-kms"
}

data "aws_ssm_parameter" "bfd_account" {
  name = "/bfd/account-id"
}

data "aws_iam_policy_document" "assume_bucket_role" {
  statement {
    actions = ["sts:AssumeRole"]
    resources = [
      "arn:aws:iam::${data.aws_ssm_parameter.bfd_account.value}:role/delegatedadmin/developer/bfd-${local.bfd_env}-eft-${var.app}-ct-bucket-role"
    ]
  }
}

module "cclf_import_function" {
  source = "../../modules/function"

  app = var.app
  env = var.env

  name        = local.full_name
  description = "Ingests the most recent CCLF from BFD"

  handler = "bootstrap"
  runtime = "provided.al2"

  memory_size = local.memory_size[var.app]

  function_role_inline_policies = {
    assume-bucket-role = data.aws_iam_policy_document.assume_bucket_role.json
  }

  environment_variables = {
    ENV      = var.env
    APP_NAME = "${var.app}-${var.env}-cclf-import"
  }
  extra_kms_key_arns = local.extra_kms_key_arns
}

# Set up queue for receiving messages when a file is added to the bucket

data "aws_ssm_parameter" "bfd_sns_topic_arn" {
  name = "/cclf-import/${var.app}/${var.env}/bfd-sns-topic-arn"
}

module "cclf_import_queue" {
  source = "../../modules/queue"

  app = var.app
  env = var.env

  name = local.full_name

  function_name = module.cclf_import_function.name
  sns_topic_arn = data.aws_ssm_parameter.bfd_sns_topic_arn.value
  policy_documents = [data.aws_iam_policy_document.sns_send_message]
}

data "aws_iam_policy_document" "sns_send_message" {

  statement {
    sid     = "SnsSendMessage"
    actions = ["sqs:SendMessage"]

    principals {
      type        = "Service"
      identifiers = ["sns.amazonaws.com"]
    }

    resources = [module.cclf_import_queue.arn]

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [data.aws_ssm_parameter.bfd_sns_topic_arn.value]
    }
  }
}

resource "aws_sns_topic_subscription" "this" {
  endpoint  = module.cclf_import_queue.arn
  protocol  = "sqs"
  topic_arn = data.aws_ssm_parameter.bfd_sns_topic_arn.value
}

# Add a rule to the database security group to allow access from the function

data "aws_security_group" "db" {
  name = local.db_sg_name
}

resource "aws_security_group_rule" "function_access" {
  type        = "ingress"
  from_port   = 5432
  to_port     = 5432
  protocol    = "tcp"
  description = "cclf-import function access"

  security_group_id        = data.aws_security_group.db.id
  source_security_group_id = module.cclf_import_function.security_group_id
}
