data "aws_caller_identity" "current" {}
# IAM role for the function
resource "aws_iam_role" "opt_out_import_lambda_role" {
  name = var.iam_role_name
  #tags = local.tags

  assume_role_policy = <<-EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": "sts:AssumeRole",
        "Principal": {
          "Service": "lambda.amazonaws.com"
        },
        "Effect": "Allow",
        "Sid": ""
      }
    ]
  }
  EOF
}

resource "aws_iam_policy" "opt_out_import_lambda_policy" {
  name = var.policy_name
  description = var.policy_description   

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AllowDecryption",
            "Effect": "Allow",
            "Action": [
                "kms:Decrypt",
                "kms:Encrypt"
            ],
            "Resource": [
               "${aws_kms_key.env_vars_kms_key.arn}"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
              "logs:CreateLogGroup",
              "logs:CreateLogStream",
              "logs:PutLogEvents"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
              "ssm:GetParameters"
            ],
           "Resource": "arn:aws:ssm:us-east-1:${data.aws_caller_identity .current.account_id}:parameter/${var.service_name}/${var.env}/consent/db_pass_${var.service_name}_consent"
        },
        {
            "Effect": "Allow",
            "Action": [
              "ssm:GetParameters"
            ],
           "Resource": "arn:aws:ssm:us-east-1:${data.aws_caller_identity .current.account_id}:parameter/${var.service_name}/${var.env}/consent/db_pass_${var.service_name}_consent"
        }
    ]
}
EOF
}
resource "aws_iam_role_policy_attachment" "opt_out_import_lambda" {
  role       = aws_iam_role.opt_out_import_lambda_role.name
  policy_arn = aws_iam_policy.opt_out_import_lambda_policy.arn
}

resource "aws_kms_key" "env_vars_kms_key" {
  description = var.key_description
  deletion_window_in_days = var.deletion_window_in_days
  enable_key_rotation = var.enable_key_rotation
}

resource "aws_kms_alias" "a" {
  name = var.kms_alias_name
  target_key_id = aws_kms_key.env_vars_kms_key.key_id
}

resource "aws_lambda_function" "opt_out_import_lambda" {
  filename         = var.filename
  source_code_hash = var.source_code_hash
  function_name    = var.function_name
  description      = var.description
  role             = var.role
  kms_key_arn      = var.kms_key_arn
  handler          = var.handler
  runtime          = var.runtime
  timeout          = var.timeout
  memory_size      = var.memory_size

  tracing_config {
    mode = "Active"
  }

  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = var.common_security_group_ids 
  }

  environment {
    variables = var.environment_variables
  }
} 
