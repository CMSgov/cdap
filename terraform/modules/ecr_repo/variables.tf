variable "platform" {
  description = "Object representing the platform module."
  type = object({
    app               = string
    env               = string
    service           = string
    kms_alias_primary = object({ target_key_arn = string })
    primary_region    = object({ name = string })
    account_id        = string
  })
}

variable "service" {
  description = "Custom service name in case multiple ECR repos made in the same terraservice. If null, defaults to platform service value."
  type        = string
  default     = null
}

variable "repo_name_override" {
  description = "When possible, do not use. Override for the name of the ECR repository."
  type        = string
  default     = null
}

variable "tag_rules" {
  description = <<-EOT
    List of lifecycle rules to apply to the ECR repository, evaluated in priority order.

    Each rule object supports the following attributes:
      - priority    (required) : Rule evaluation order — lower numbers are evaluated first.
      - tag_prefix  (optional) : Image tag prefix to match (e.g. "release-", "v").
                                 When set, the rule targets only images whose tags start
                                 with this prefix (tagStatus = "tagged").
                                 When null, the rule targets ALL images regardless of
                                 tag status (tagStatus = "any") — this includes both
                                 tagged and untagged images not matched by earlier rules.
      - keep_count  (required) : Number of images to retain matching this rule.

    IMPORTANT — null tag_prefix behavior:
    Rules with tag_prefix = null use tagStatus = "any", which means they act as a
    catch-all and will expire BOTH tagged and untagged images beyond keep_count.
    Untagged image retention is NOT exclusively controlled by untagged_expiry_days
    when a null-prefix rule is present — the null-prefix rule will also affect
    untagged images. If you need untagged images to be retained independently,
    do not use a null-prefix tag_rule; rely solely on untagged_expiry_days instead.

    Example:
      tag_rules = [
        {
          priority   = 10
          tag_prefix = "release-"
          keep_count = 10
        },
        {
          priority   = 20
          tag_prefix = null       # Catch-all: applies to ALL remaining images (tagged + untagged)
          keep_count = 5
        }
      ]
  EOT
  type = list(object({
    priority   = number
    tag_prefix = optional(string, null)
    keep_count = number
  }))
  default = []
}

variable "untagged_expiry_days" {
  description = <<-EOT
    Number of days after which untagged images are expired.

    NOTE: This variable only has exclusive control over untagged image retention
    when no tag_rules entry has tag_prefix = null. If a null-prefix tag_rule exists,
    that rule's tagStatus = "any" will also match untagged images and may expire them
    before untagged_expiry_days is reached, depending on rule priority order.

    Set to null to disable the untagged expiry rule entirely.
  EOT
  type    = number
  default = 14
}
