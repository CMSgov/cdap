variable "apps_served" {
    description = "List of the applications served by their names used in tags."
    type = list(string)
    default = ["ab2d", "bbapi", "bcda", "cdap", "dpc"]
}

variable "env" {
  description = "The application environment (dev, test, sbx, sandbox, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "test", "sbx", "sandbox", "prod"], var.env)
    error_message = "Valid value for env is dev, test, sbx, sandbox, or prod."
  }
}
