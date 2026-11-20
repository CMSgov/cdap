# EventBridge rule tftesting terraservice

Exercises `terraform/modules/event_rule` in cdap-test.

## Turning it on and off

`config/test.yml` holds the flag:

```yaml
event_rule:
  enabled: true
```

`conf.sh` targets `cdap-test`, so once a change with `enabled: true` is merged to main, the tofu-apply workflow applies this service there. Set it back to `false` when testing is done; the next apply destroys every resource here. For a local run, `-var event_rule_enabled=true` overrides the file.

## What gets created when enabled

| Resource | Exercises |
| -------- | --------- |
| `cdap-test-tftesting-pattern` rule | `event_pattern`, two targets, `retry_policy`, automatic Lambda permission |
| `cdap-test-tftesting-schedule` rule | `schedule_expression`, fixed `input` |
| `cdap-test-tftesting-event-rule` Lambda | Receives both rules' events |
| `cdap-test-tftesting-event-rule` SNS topic | SNS target with `allow_eventbridge_publish`, as AB2D uses |
| `/cdap/test/tftesting/event-rule/last-received` | Where the Lambda records each round-trip event |

## How the apply validates the rule

After the rules are created, `aws_lambda_invocation.roundtrip_check` invokes the Lambda with `RoundTripCheck`. From the VPC's private subnets the Lambda puts a `cdap.tftesting` event on the default bus with a fresh nonce, then waits up to 45 seconds for the pattern rule to deliver that event back to it and for the nonce to appear in SSM. If it doesn't, the Lambda raises and `tofu apply` fails. A pass shows that the event pattern matches, the target is attached, the Lambda permission works, and in-VPC code can reach EventBridge.

The check re-runs whenever the rule or the Lambda code changes. SNS delivery isn't asserted; check the topic's delivery logs or the rule's `FailedInvocations` metric if needed.
