variable "repo_name" {
  description = "Repo name used to construct the CI role name ($${repo_name}-$${env}-github-actions). For this terraservice, that's \"cdap\"."
  type        = string
  default     = "cdap"
}
