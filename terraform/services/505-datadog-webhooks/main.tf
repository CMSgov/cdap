##
# Integrations
##

# Victorops / Splunk Alerting
## This integration was set up manually as there is no Tofu resource defined
## The integration is turned on in Victorops and a token is provided, which is stored in
## SOPS for continuity of use. In the Datadog GUI, the integration is configured
## with the endpoints as defined in https://portal.victorops.com/dash/bcda#/routekeys


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
    threshold  = "$ALERT_THRESHOLD"
    message    = "$TEXT_ONLY_MSG"
    host       = "$HOSTNAME"
    tags       = "$TAGS"
    link       = "$LINK"
    snapshot   = "$SNAPSHOT"
    alert_type = "$ALERT_TYPE"
    date       = "$DATE"
  })
}
