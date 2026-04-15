output "datadog_application_key" {
    description = "Key for ${var.app} for CICD use in ${var.account_env_suffix}"
    value = datadog_application_key
    sensitive = true
}
