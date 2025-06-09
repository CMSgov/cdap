/*variable "app" {
  description = "The application name (ab2d, bcda, dpc)"
  type        = list(string)
}*/
variable "app" {
  description = "The application name(s) to use for ECR scan (ab2d, bcda, dpc)"
  type        = list(string)
  default     = []
  validation {
    condition     = alltrue([for a in var.app : contains(["ab2d", "bcda", "dpc"], a)])
    error_message = "Each app must be one of: ab2d, bcda, dpc"
  }
}

locals {
  # If app list is empty (no input), default to all 3 apps
  app_list = length(var.app) > 0 ? var.app : ["ab2d", "bcda", "dpc"]
}
