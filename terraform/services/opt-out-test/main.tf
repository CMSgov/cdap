module "test_bucket" {
  source = "../../modules/bucket"
  name   = "${var.app}-${var.env}-opt-out-test"
}

module "test_topic" {
  source  = "../../modules/topic"
  name    = "${var.app}-${var.env}-opt-out-test"
  buckets = [module.test_bucket.arn]
}
