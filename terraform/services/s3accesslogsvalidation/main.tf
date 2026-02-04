module "s3logsvalidationbucket" {
  source      = "../../modules/bucket"
    app = "cdap"
    env = "test"
    name = "s3logsvalidation"
    }

