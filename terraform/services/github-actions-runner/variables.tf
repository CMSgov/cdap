variable "key_base64" {
  description = "Private key for the GitHub App. Ensure the key is the base64-encoded `.pem` file (the output of `base64 app.private-key.pem`, not the content of `private-key.pem`)."
  type        = string
}

variable "app_id" {
  description = "GitHub App ID"
  type        = string
}

variable "webhook_secret" {
  description = "Webhook secret for the GitHub App (also known as the Client Secret)"
  type        = string
}

variable "ami_account" {
  description = "Account number for AMI owner"
  type        = string
}
