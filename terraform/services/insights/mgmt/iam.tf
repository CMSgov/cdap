resource "aws_iam_role" "this" {
  assume_role_policy = jsonencode(
    {
      Statement = [
        {
          Action = "sts:AssumeRole"
          Effect = "Allow"
          Principal = {
            Service = "quicksight.amazonaws.com"
          }
        },
      ]
      Version = "2012-10-17"
    }
  )
  force_detach_policies = true
  max_session_duration  = 3600
  name                  = "${local.service_prefix}-quicksight-service"
  path                  = "/service-role/"
}

# Basic Policy Attachments, Further Attachments Necessary
resource "aws_iam_role_policy_attachment" "this" {
  for_each = toset([
    "arn:aws:iam::aws:policy/service-role/AmazonSageMakerQuickSightVPCPolicy", #AWS-managed, allowing CRUD on ENIs, Limited VPC Resources
    "arn:aws:iam::aws:policy/service-role/AWSQuickSightListIAM",               #AWS-managed, allows `iam:List*`
    "arn:aws:iam::aws:policy/service-role/AWSQuicksightAthenaAccess",          #AWS-managed, allows access to glue, athena, and athena-related s3 resources
  ])

  role       = aws_iam_role.this.name
  policy_arn = each.value
}
