# The address used is from the 203.0.113.0/24 range reserved for
# documentation, which should be unresolvable in any network. It
# is only used as a placeholder, and should be overwritten by
# other processes when managing addresses in these IP sets.

resource "aws_wafv2_ip_set" "regional" {
  name               = "external-services-regional"
  description        = "IP ranges for Zscaler, New Relic, etc."
  scope              = "REGIONAL"
  ip_address_version = "IPV4"
  addresses          = ["203.0.113.0/32"]

  lifecycle {
    ignore_changes = [
      addresses,
    ]
  }
}

resource "aws_wafv2_ip_set" "cloudfront" {
  name               = "external-services-cloudfront"
  description        = "IP ranges for Zscaler, New Relic, etc."
  scope              = "CLOUDFRONT"
  ip_address_version = "IPV4"
  addresses          = ["203.0.113.0/32"]

  lifecycle {
    ignore_changes = [
      addresses,
    ]
  }
}
