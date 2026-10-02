variable "platform" {
  description = "Object that describes standardized platform values. Must expose app, env, service, and kms_alias_primary.target_key_arn."
  type        = any
}

variable "name" {
  description = <<-EOT
    Short name for this topic's purpose, e.g. "alarms" or "alarm-to-slack".
    Used to construct the default topic name and, if enabled, the default
    SSM parameter path.
  EOT
  type        = string
}

variable "topic_name_override" {
  description = <<-EOT
    Overrides the constructed topic name ({platform.app}-{platform.env}-
    {name}) entirely. SNS topic names are immutable in AWS -- changing
    this later forces the topic to be destroyed and recreated. Required
    when adopting this module for an existing topic whose name predates
    this convention.
  EOT
  type        = string
  default     = null
}

variable "kms_key_override" {
  description = "Do not favor. Override to the platform-managed KMS key. Defaults to var.platform.kms_alias_primary.target_key_arn."
  type        = string
  default     = null
}

variable "buckets" {
  description = <<-EOT
    ARNs of S3 buckets that need to publish event notifications to this
    topic. When non-empty, adds a topic policy statement allowing
    s3.amazonaws.com to publish.
  EOT
  type        = list(string)
  default     = []
}

variable "allow_cloudwatch_publish" {
  description = "If true, grants cloudwatch.amazonaws.com sns:Publish on this topic. Needed when a CloudWatch alarm targets this topic as an alarm action."
  type        = bool
  default     = false
}

variable "allow_eventbridge_publish" {
  description = "If true, grants events.amazonaws.com sns:Publish on this topic. Needed when an EventBridge rule targets this topic."
  type        = bool
  default     = false
}

variable "additional_publisher_service_principals" {
  description = "Additional AWS service principals (e.g. \"ec2.amazonaws.com\") granted sns:Publish on this topic."
  type        = list(string)
  default     = []
}

variable "additional_publisher_iam_arns" {
  description = <<-EOT
    IAM role/user ARNs granted sns:Publish directly on this topic. This
    module does not create those IAM identities -- it only grants the
    topic-side resource policy statement; the consuming terraservice owns
    the role/user itself.
  EOT
  type        = list(string)
  default     = []
}

variable "sqs_subscriptions" {
  description = "Names of existing SQS queues (looked up by name, not created by this module) to subscribe to this topic."
  type        = list(string)
  default     = []
}

variable "additional_subscriptions" {
  description = "Non-SQS subscriptions, e.g. VictorOps via https, or email."
  type = list(object({
    protocol = string
    endpoint = string
  }))
  default = []
}

variable "create_ssm_parameter" {
  description = <<-EOT
    Publishes this topic's ARN to SSM Parameter Store, at
    ssm_parameter_name_override if set, otherwise at the default path
    constructed from platform.app, platform.env, platform.service, and
    var.name. Off by default -- not every topic needs to be discoverable
    by other terraservices.
  EOT
  type        = bool
  default     = false
}

variable "ssm_parameter_name_override" {
  description = "Overrides the constructed SSM parameter path entirely. Only used when create_ssm_parameter = true."
  type        = string
  default     = null
}
