module "datadog_dashboard" {
  source = "../../modules/datadog_dashboard"

  app = "cdap"

  enable_default_widgets = {
    ecs    = true
    alb    = false
    aurora = false
    sns    = false
    sqs    = true
    lambda = true
    s3     = true
    apm    = false
  }

  widget_live_spans = {
    current = "15m"
    ecs     = "1d"
    alb     = "4h"
    aurora  = "4h"
    sns     = "4h"
    sqs     = "4h"
    lambda  = "1d"
    s3      = "1w"
    apm     = "1d"
  }

  custom_widgets = []
  runbook_url    = "https://definerunbook.cdap.internal.cms.gov" #FIXME to provide an actual runbook
}

module "standards" {
  source    = "../../modules/standards"
  providers = { aws = aws, aws.secondary = aws.secondary }

  app          = "cdap"
  env          = var.env
  root_module  = "https://github.com/CMSgov/cdap/tree/main/terraform/services/${basename(abspath(path.module))}/"
  service      = replace(basename(abspath(path.module)), "/^[0-9]+-/", "")
  ssm_root_map = { datadog = "/cdap/${var.env}/datadog/cicd/" }
}
