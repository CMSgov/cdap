variable "repo_name" {
  description = "Repo name used to construct the CI role name ($${repo_name}-$${env}-github-actions). For this terraservice, that's \"cdap\"."
  type        = string
  default     = "cdap"
}

variable "enable_human_database_access" {
  description = <<-EOT
    Controls whether this terraservice creates the human-facing IAM
    database access path at all (a dedicated role, its trust policy, and
    the rds-db:connect permission). Defaults to false.

    Unlike breakglass access (alerted via EventBridge on Secrets Manager
    GetSecretValue) and CI access (one identity, one pipeline, fully
    logged), IAM database auth as tftesting_human produces no alarm and
    no per-person accountability at the Postgres level. Leave this off
    unless there's a specific reason to turn it on.
  EOT
  type        = bool
  default     = false
}

variable "human_access_admin_role_names" {
  description = "Names of existing IAM roles allowed to assume the dedicated human-db-access role."
  type        = list(string)
  default     = ["ct-ado-bcda-application-admin"]
}
