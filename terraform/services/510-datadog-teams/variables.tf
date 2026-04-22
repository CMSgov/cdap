variable "app_teams" {
  description = "List of teams with access in DASG APIs Datadog"
  type        = list(string)
  default = [
    "ab2d",
    "bbapi",
    "bcda",
    "cdap",
    "dpc"
  ]
}
