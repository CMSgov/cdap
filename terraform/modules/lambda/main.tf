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
  description =  "Beneficiary Opt-Out Lambda Policy"  

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
           "Resource": "arn:aws:ssm:us-east-1:${data.aws_caller_identity .current.account_id}:parameter/*"
        },
        {
            "Effect": "Allow",
            "Action": [
              "ssm:GetParameters"
            ],
           "Resource": "arn:aws:ssm:us-east-1:${data.aws_caller_identity .current.account_id}:parameter/*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "ec2:DescribeNetworkInterfaces",
                "ec2:CreateNetworkInterface",
                "ec2:DeleteNetworkInterface"
            ],
            "Resource": "*"
        },
         {
        "Effect" = "Allow",
        Action = ["s3:GetObject", "s3:ListBucket"],
        Resource = [
          "arn:aws:s3:::"lambda-zip-file-storage-${var.account_number}-${var.team_name}"/*",
          "arn:aws:s3:::"lambda-zip-file-storage-${var.account_number}-${var.team_name}"",
        ],
      },
    ],
}
EOF
}
resource "aws_iam_role_policy_attachment" "opt_out_import_lambda" {
  role       = aws_iam_role.opt_out_import_lambda_role.name
  policy_arn = aws_iam_policy.opt_out_import_lambda_policy.arn
}

resource "aws_kms_key" "env_vars_kms_key" {
  description = "opt-out-import-env-vars"
  deletion_window_in_days = 10
  enable_key_rotation = true
}

resource "aws_kms_alias" "a" {
  name = "alias/opt-out-import-env-vars"
  target_key_id = aws_kms_key.env_vars_kms_key.key_id
}

resource "aws_s3_bucket" "lambda_zip_file" {
  bucket = var.s3_bucket
  acl    = "private"
  versioning {
    enabled = true
  }
}

resource "aws_lambda_function" "opt_out_import_lambda" {
  description      = "Ingests the most recent beneficiary opt-out list from BFD"
  function_name    = var.function_name
  s3_key           = var.s3_object_key
  s3_bucket        = var.s3_bucket
  role             = var.role
  handler          = var.handler
  runtime          = var.runtime
  kms_key_arn      = "arn:aws:kms:us-east-1:${var.account_number}:key/${var.team_name}-kms-key-arn"
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
