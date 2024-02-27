module "test_bucket" {
  source = "../../modules/bucket"
  name   = "${var.app}-${var.env}-opt-out-test"
}

module "test_topic" {
  source  = "../../modules/topic"
  name    = "${var.app}-${var.env}-opt-out-test"
  buckets = [module.test_bucket.arn]
}

resource "aws_s3_bucket_notification" "this" {
  bucket = module.test_bucket.id

  topic {
    topic_arn     = module.test_topic.arn
    events        = ["s3:ObjectCreated:*"]
    filter_prefix = "oot01/"
  }
}
