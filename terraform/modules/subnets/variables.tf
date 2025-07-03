variable "vpc_id" {
  description = "ID for the AWS VPC"
  type        = string
}

variable "use" {
  description = "The use, private or public, for the subnet"
  type        = string
  default     = "private"
  validation {
    condition     = contains(["private", "public"], var.use)
    error_message = "Valid value for use is private or public."
  }
}
