variable "platform" {
  description = "Object representing the CDAP platform module."
  type = object({
    app             = string
    env             = string
    service         = string
    vpc_id          = string
    private_subnets = map(object({ id = string }))
  })
}

variable "service_name" {
  description = "VPC endpoint service_name (vpce-svc-...) to connect to. Provide this or ssm_parameter_name, not both."
  type        = string
  default     = null
}

variable "ssm_parameter_name" {
  description = <<-EOT
    SSM parameter path to read the endpoint service_name from, published by
    the producer's lb module (privatelink_ssm_parameter_name output).
    Provide this or service_name, not both.
  EOT
  type        = string
  default     = null

  validation {
    condition     = (var.service_name == null) != (var.ssm_parameter_name == null)
    error_message = "Provide exactly one of service_name or ssm_parameter_name."
  }
}

variable "dns_record_name" {
  description = "Subdomain label for the friendly CNAME, e.g. 'bcda-target'. Required if create_friendly_dns_record is true."
  type        = string
  default     = null
}
