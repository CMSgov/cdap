variable "app" {
  description = "[\"ab2d\", \"bcda\", \"dpc\", \"cdap\"] The application name."
  type        = string
  validation {
    condition     = contains(["ab2d", "bcda", "dpc", "cdap"], var.app)
    error_message = "Valid value for app is ab2d, bcda, dpc, or cdap."
  }
}

variable "env" {
  description = "[\"dev\", \"test\", \"sandbox\", \"prod\"] The environment that leverages this key."
  type        = string
  validation {
    condition     = contains(["dev", "test", "sandbox", "prod", "non-prod"], var.env)
    error_message = "Valid value for app is dev, test, sandbox, or prod."
  }
}

variable "name_suffix" {
  description = "[\"cicd\" or \"agents\"]The suffix for this API key. API usage is limited to 50 keys in the Datadog organization."
  type        = string
  validation {
    condition     = contains(["cicd", "agents"], var.name_suffix)
    error_message = "Valid value for name_suffix is cicd or agents."
  }
}
