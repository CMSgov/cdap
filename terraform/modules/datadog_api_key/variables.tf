variable "app" {
  description = "[\"ab2d\", \"bcda\", \"dpc\", \"cdap\"] The application name."
  type        = string
  validation {
    condition     = contains(["ab2d", "bcda", "dpc", "cdap", "bbapi"], var.app)
    error_message = "Valid value for app is ab2d, bcda, dpc, or cdap."
  }
}

variable "env" {
  description = "[\"dev\", \"test\", \"sandbox\", \"prod\", \"non-prod\"] The environment that leverages this key."
  type        = string
  validation {
    condition     = contains(["dev", "test", "sandbox", "prod", "non-prod"], var.env)
    error_message = "Valid value for app is dev, test, sandbox, or prod."
  }
}

variable "used_for" {
  description = "[\"cicd\" or \"agents\"]The suffix for this API key. API usage is limited to 50 keys in the Datadog organization."
  type        = string
  validation {
    condition     = contains(["cicd", "agents"], var.used_for)
    error_message = "Valid value for used_for is cicd or agents."
  }
}
