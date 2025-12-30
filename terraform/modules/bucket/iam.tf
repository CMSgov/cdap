# Only write to this S3 Bucket

data "aws_iam_policy_document" "write_to_bucket" {
  statement {
    sid = "ListBucketAndGetLocation"

    actions = [
      "s3:GetBucketLocation",
      "s3:ListBucket"
    ]

    resources = [
      "&{aws_s3_bucket.this.arn}"
    ]
  }

  statement {
      sid = "WriteObjects"

    actions = [
      "s3:PutObject",
      "s3:PutObjectVersion"
    ]

    resources = [
      "&{aws_s3_bucket.this.arn}/*"
    ]
}

resource "aws_iam_policy" "write_to_bucket" {
  name        = "${aws_s3_bucket.this.id}-write-only"
  path        = "delegatedadmin/developer"
  description = "Grants access to write to ${aws_s3_bucket.this.id}"
  policy = data.aws_iam_policy_document.write_to_bucket
}

# Only write to this S3 Bucket

data "aws_iam_policy_document" "read_bucket" {
  statement {
    sid = "ListBucketAndGetLocation"

    actions = [
      "s3:GetBucketLocation",
      "s3:ListBucket"
    ]

    resources = [
      "&{aws_s3_bucket.this.arn}"
    ]
  }

  statement {
      sid = ""

    actions = [
        "s3:GetObject",
        "s3:GetObjectTagging",
        "s3:GetObjectVersion",
        "s3:GetObjectVersionTagging",
    ]

    resources = [
      "&{aws_s3_bucket.this.arn}/*"
    ]
}

resource "aws_iam_policy" "read_from_bucket" {
  name        = "${aws_s3_bucket.this.id}-read"
  path        = "delegatedadmin/developer"
  description = "Grants access to read ${aws_s3_bucket.this.id}"
   policy = data.aws_iam_policy_document.read_from_bucket
}

# Only delete from S3 Bucket, includes full paths


data "aws_iam_policy_document" "delete_from_bucket" {
  statement {
    sid = "ListBucketAndGetLocation"

    actions = [
      "s3:GetBucketLocation",
      "s3:ListBucket"
    ]

    resources = [
      "&{aws_s3_bucket.this.arn}"
    ]
  }

  statement {
      sid = ""

    actions = [
      "s3:DeleteObject",
      "s3:DeleteObjectVersion"
    ]

    resources = [
      "&{aws_s3_bucket.this.arn}/*"
    ]
}
resource "aws_iam_policy" "delete" {
  name        = "${aws_s3_bucket.this.id}-delete-only"
  path        = "delegatedadmin/developer"
  description = "Grants access to read ${aws_s3_bucket.this.id}"
  policy = data.aws_iam_policy_document.delete_from_bucket
}

