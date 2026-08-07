##
# Integrations
##

# Slack
## CMS enables use of webhooks not of the Datadog-Slack Integration.
## Before adding a new webhook here, add a new workflow in slack
## Build the workflow by duplicating existing workflows or
### reference the payload below for variable creation
### add a step to write to a slack channel
### add a body that compiles your payload into an understandable message


resource "datadog_webhook" "slack_channels" {
  for_each = nonsensitive(module.standards.ssm.datadog_slack_webhooks)

  name = "slack-${each.key}"
  url  = sensitive(each.value.value)

  encode_as = "json"
  custom_headers = jsonencode({
    "Content-Type" = "application/json"
  })
  payload = jsonencode({
    title      = "$EVENT_TITLE"
    status     = "$ALERT_STATUS"
    priority   = "$PRIORITY"
    metric     = "$ALERT_METRIC"
    message    = "$TEXT_ONLY_MSG"
    host       = "$HOSTNAME"
    tags       = "$TAGS"
    link       = "$LINK"
    snapshot   = "$SNAPSHOT"
    alert_type = "$ALERT_TYPE"
    date       = "$DATE"
  })
  lifecycle {
    create_before_destroy = false # destroy first to avoid name conflicts
  }
}

locals {
  victorops_message_types = [
    "CRITICAL",
    "WARNING",
    # "ACKNOWLEDGEMENT",
    # "INFO"
    "RECOVERY"
  ]

  victorops_webhooks = [for pair in setproduct(module.standards.ssm.datadog_victorops_webhooks, local.victorops_message_types) : { hook = pair[0], message_type = pair[1] }]
}

# Victorops
## Requires a Rest integration to be set up and will instantiate for every
## SSM parameter in the account at the defined path in standards
resource "datadog_webhook" "victorops_endpoints" {
  for_each = { for obj in local.victorops_webhooks : "${obj.hook.key}-${lower(obj.message_type)}" => obj }

  name = "victorops-${each.key}"
  url  = sensitive(each.value.hook.value)

  encode_as = "json"
  custom_headers = jsonencode({
    "Content-Type" = "application/json"
  })
  payload = jsonencode({
    message_type        = each.value.message_type
    entity_id           = "$EVENT_TITLE"   # Unique identifier for the alert (used for deduplication)
    entity_display_name = "$EVENT_TITLE"   # Human-readable name shown in VictorOps
    state_message       = "$TEXT_ONLY_MSG" # Alert body/description
    state_start_time    = "$DATE_POSIX"    # Unix timestamp of when the alert started
    monitoring_tool     = "Datadog"        # Identifies the source tool
    host_name           = "$HOSTNAME"      # Affected host
    metric_name         = "$ALERT_METRIC"  # The metric that triggered the alert
    tags                = "$TAGS"
    link                = "$LINK"
    priority            = "$PRIORITY"
  })
  lifecycle {
    create_before_destroy = false # destroy first to avoid name conflicts
  }
}
