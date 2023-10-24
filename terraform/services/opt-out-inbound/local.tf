locals {
  bfd_env          = var.team_name == "dpc" ? (var.env == "dev" || var.env == "test" ? "test" : "prod") : ""
}
