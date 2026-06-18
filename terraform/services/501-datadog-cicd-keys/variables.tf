variable "env" {
  description = "The application environment (dev, test, sandbox, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "sandbox", "test", "prod"], var.env)
    error_message = "Valid value for env is dev, test, sandbox, or prod."
  }
}

variable "app" {
  description = "[\"ab2d\", \"bcda\", \"dpc\", \"cdap\", \"bb\"] The application name."
  type        = string
  validation {
    condition     = contains(["ab2d", "bcda", "dpc", "cdap", "bb"], var.app)
    error_message = "Valid value for app is ab2d, bcda, dpc, or cdap."
  }
}
