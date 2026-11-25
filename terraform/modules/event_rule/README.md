# EventBridge (CloudWatch Event) rule module

Creates one EventBridge rule, its targets, and the Lambda invoke permissions those targets need.
The rule fires on either a schedule (`schedule_expression`) or an event pattern (`event_pattern`), never both.

The rule is named `{app}-{env}-{name}`. Teams adopting an existing rule can keep its name with `rule_name_override`, and keep each target's ID by using it as the key in `targets`, so adoption is a `moved` block rather than a replacement.

## What the module does and doesn't own

| Concern | Owner |
| ------- | ----- |
| Rule, targets, retry policy, DLQ wiring | This module |
| `lambda:InvokeFunction` for Lambda targets | This module (`manage_lambda_permissions = true` by default) |
| `sns:Publish` on an SNS target | The topic. With `modules/topic`, set `allow_eventbridge_publish = true` |
| `sqs:SendMessage` on an SQS target | The queue's policy, conditioned on this module's `arn` output |
| KMS key access for encrypted SNS/SQS targets | The key policy must allow `events.amazonaws.com` to use the key |
| Network path for in-VPC code calling `PutEvents` | The shared EventBridge interface endpoint (`com.amazonaws.<region>.events`); nothing to configure here |

## Usage

### Event pattern to an SNS topic (AB2D ECS task monitoring)

```hcl
module "task_monitoring_rule" {
  source   = "github.com/CMSgov/cdap//terraform/modules/event_rule?ref=<sha>"
  platform = module.platform

  name               = "task-monitoring"
  rule_name_override = "${local.service_prefix}-${local.service}-task-monitoring-rule" # keep the existing name
  description        = "This rule captures the last status of task definitions"

  event_pattern = jsonencode({
    source        = ["aws.ecs"]
    "detail-type" = ["ECS Task State Change"]
    detail = {
      clusterArn = [module.cluster.this.arn]
      lastStatus = ["RUNNING"]
    }
  })

  targets = {
    SendToSNS = { arn = aws_sns_topic.this.arn } # existing target ID kept as the key
  }
}

moved {
  from = aws_cloudwatch_event_rule.this
  to   = module.task_monitoring_rule.aws_cloudwatch_event_rule.this
}

moved {
  from = aws_cloudwatch_event_target.this
  to   = module.task_monitoring_rule.aws_cloudwatch_event_target.this["SendToSNS"]
}
```

### Schedule to a Lambda function

```hcl
module "audit_schedule" {
  source   = "github.com/CMSgov/cdap//terraform/modules/event_rule?ref=<sha>"
  platform = module.platform

  name                = "audit"
  schedule_expression = "rate(1 day)"

  targets = {
    lambda = { arn = module.audit_function.function_arn }
  }
}
```

### Shaping the delivered event

Each target can set one of `input` (a fixed JSON string), `input_path` (a JSONPath into the event) or `input_transformer`:

```hcl
targets = {
  lambda = {
    arn = module.fn.function_arn
    input_transformer = {
      input_paths    = { status = "$.detail.lastStatus" }
      input_template = "{\"status\": <status>}"
    }
    retry_policy = { maximum_retry_attempts = 3 }
  }
}
```

## Testing

`terraform/services/613-tftesting-event-rule` exercises this module in cdap-test. See its README.

<!-- BEGIN_TF_DOCS -->
<!-- END_TF_DOCS -->
