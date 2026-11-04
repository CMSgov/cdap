resource "datadog_monitor_config_policy" "env_tag" {
  policy_type = "tag"
  tag_policy {
    tag_key          = "environment"
    tag_key_required = true
    valid_tag_values = ["dev", "test", "stage", "sandbox", "prod"]
  }
}

resource "datadog_sensitive_data_scanner_group" "main" {
  name        = "Shared sensitive data scanning group"
  description = "Group shared by all teams."
  filter {
    query = "*"
  }
  is_enabled   = true
  product_list = ["rum", "events", "apm"]

  samplings {
    product = "rum"
    rate    = 100
  }

  samplings {
    product = "events"
    rate    = 100
  }

  samplings {
    product = "apm"
    rate    = 100
  }
}

locals {
  selected_standard_rules = [
    "OfGqX8R9TRqAcorxenl2fQ",                   // AWS Access Key ID Scanner
    "UdHPBTHIbv0pYpj5EB1FeN",                   // AWS Bedrock Long-Term API Key Scanner
    "VODEG8SFzIkOURt88sGScv",                   // AWS Bedrock Short-Term API Key Scanner
    "iZeqWOvYThWJ7DWMwIQoRg",                   // AWS Secret Access Key Scanner
    "6wNOSkZcL2AhnKbafQi11t",                   // AWS Session Token Scanner
    "mZy8XjZLReC9smpERXWnnw",                   // Bearer Token Scanner
    "lQbN5LgeZVePS6H5WtapAd",                   // Data.gov API Key Scanner
    "Pus1fLRQXer1olidwu7Lvc",                   // Datadog API Key Scanner
    "R00RCN2HgIX9ZiYW7itxmp",                   // Datadog Application Key Scanner
    "E0XITGjhlcjl6K2U5nlBKH",                   // Datadog Nonce Session Token Scanner
    "QCeNNKM7lVg0g1SybCYtrp",                   // Datadog OAuth Tokens Scanner
    "m9t9lqUIALHgB5eL0gU6Qx",                   // Datadog Personal Access Token Scanner
    "T6HEh6rDgMD2OMo8LfDpPN",                   // Datadog Prefixed Application Key Scanner
    "9osY3xc9Q7ONAV0zw9Uz4A",                   // Generic JSON Web Token Scanner
    "5rjXkBMvQ3GbbYrpVP_HdQ",                   // Github Access Token Scanner
    "uxwF34hFEj06U8DGRkJKSa",                   // Github Fine-grained Personal Access Token Scanner
    "OMuUuImtTFCzF-duF0HxDQ",                   // Github Refresh Token Scanner
    "9d7756e343cefa22a5c098e1092590f806eb5446", // HTTP Basic Authentication Header Scanner
    "34574e54c3e67a8a26d7070f331d83ae933d2730", // HTTP Cookie Scanner
    "UMRNH6kmFg3AKXeskzhSN0",                   // Passport Scanner
    "gr8djMkVmPfoEJliucO9Sg",                   // Phone Number Scanner
    "A0fNRj-TQ06KnRznwcQpdQ",                   // SSH Key Scanner
    "PuXiVTCkTHOtj0Yad1ppsw",                   // Standard Email Address Scanner
    "DjdAncIYjaW4DsYlxSxawX",                   // US DEA Number Scanner
    "VYmG4oPTrNJBxKLsWzQcHd",                   // US Driver’s License Number Scanner
    "ob2KBgVCJB7j9MLFMDY4Ig",                   // US National Provider Identifier Number Scanner
    "d962f7ddb3f55041e39195a60ff79d4814a7c331", // US Passport Scanner
    "PIIXqwUljp4BaqIHDBBLNn",                   // US Social Security Number Scanner
    "eC0YxRYEz27UOrfQ7sM3Bx",                   // US Tax Identification Number Scanner
    "ac6d683cbac77f6e399a14990793dd8fd0fca333", // US Vehicle Identification Number Scanner
  ]
}

data "datadog_sensitive_data_scanner_standard_pattern" "selected_standard_rules" {
  for_each = toset(local.selected_standard_rules)

  standard_pattern_id = each.value
}

resource "datadog_sensitive_data_scanner_rule" "selected_standard_rules" {
  for_each = data.datadog_sensitive_data_scanner_standard_pattern.selected_standard_rules[*].id

  lifecycle {
    // This meta-argument avoids disabling the group when modifying the
    // `included_keyword_configuration` field
    create_before_destroy = true
  }

  group_id   = datadog_sensitive_data_scanner_group.main.id
  is_enabled = true

  standard_pattern_id = each.value

  tags = ["managed-by:tofu"]
}

resource "datadog_sensitive_data_scanner_rule" "dot_client_id" {
  lifecycle {
    // This meta-argument avoids disabling the group when modifying the
    // `included_keyword_configuration` field
    create_before_destroy = true
  }

  name        = "Django OAuth Toolkit Client IDs"
  description = "Client IDs generated for OAuth applications in the Django OAuth Toolkit"

  pattern = "\\b\\w{40}\\b"

  included_keyword_configuration {
    keywords        = ["client", "id"]
    character_count = 50
  }

  group_id   = datadog_sensitive_data_scanner_group.main.id
  is_enabled = true

  tags = ["managed-by:tofu"]
}

resource "datadog_sensitive_data_scanner_rule" "dot_client_secret" {
  lifecycle {
    // This meta-argument avoids disabling the group when modifying the
    // `included_keyword_configuration` field
    create_before_destroy = true
  }

  name        = "Django OAuth Toolkit Client Secrets"
  description = "Client secrets generated for OAuth applications in the Django OAuth Toolkit"

  pattern = "\\b\\w{128}\\b"

  included_keyword_configuration {
    keywords        = ["client", "secret"]
    character_count = 50
  }

  group_id   = datadog_sensitive_data_scanner_group.main.id
  is_enabled = true

  tags = ["managed-by:tofu"]
}

resource "datadog_sensitive_data_scanner_rule" "dot_access_token" {
  lifecycle {
    // This meta-argument avoids disabling the group when modifying the
    // `included_keyword_configuration` field
    create_before_destroy = true
  }

  name        = "Django OAuth Toolkit Access Tokens"
  description = "Access tokens generated for OAuth applications in the Django OAuth Toolkit"

  pattern = "\\b\\w{30}\\b"

  included_keyword_configuration {
    keywords        = ["access", "token"]
    character_count = 50
  }

  group_id   = datadog_sensitive_data_scanner_group.main.id
  is_enabled = true

  tags = ["managed-by:tofu"]
}

resource "datadog_sensitive_data_scanner_rule" "bb_encrypted_values" {
  lifecycle {
    // This meta-argument avoids disabling the group when modifying the
    // `included_keyword_configuration` field
    create_before_destroy = true
  }

  name        = "Blue Button Values"
  description = "Encrypted database values from Blue Button"

  pattern = "pbkdf2_sha256$[$\\w=]+"

  group_id   = datadog_sensitive_data_scanner_group.main.id
  is_enabled = true

  tags = ["managed-by:tofu"]
}

resource "datadog_sensitive_data_scanner_rule" "mbi" {
  lifecycle {
    // This meta-argument avoids disabling the group when modifying the
    // `included_keyword_configuration` field
    create_before_destroy = true
  }

  name        = "Medicare Beneficiary Identifier"
  description = "Medicare Beneficiary Identifier"

  pattern = "(?i)\\b[1-9][ACDEFGHJKMNPQRTUVWXY][ACDEFGHJKMNPQRTUVWXY0-9][0-9]-?[ACDEFGHJKMNPQRTUVWXY][ACDEFGHJKMNPQRTUVWXY0-9][0-9]-?[ACDEFGHJKMNPQRTUVWXY]{2}[0-9]{2}\\b"

  group_id   = datadog_sensitive_data_scanner_group.main.id
  is_enabled = true

  tags = ["managed-by:tofu"]
}
