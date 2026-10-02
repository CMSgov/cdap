variable "username" {
  description = "Breakglass username for the test cluster. Appended to normal service prefix."
  type        = string
  default     = "tftesting"
}

variable "instance_class" {
  description = <<-EOT
    Instance class for the test cluster. Restricted to the same RI-eligible
    classes as the aurora module (db.r8g.large/xlarge/2xlarge) since this
    still draws from the same reserved instance pool -- keep this on the
    smallest class unless a specific test needs more.
  EOT
  type        = string
  default     = "db.r8g.large"
}

variable "maintenance_window" {
  description = "Maintenance window passed to the aurora module."
  type        = string
  default     = "sun:05:00-sun:05:30"
}

variable "backup_window" {
  description = "Backup window passed to the aurora module."
  type        = string
  default     = "04:00-04:30"
}
