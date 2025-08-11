output "sopsw" {
  description = "When `var.create_local_sops_wrapper` true, output tui/cli command for editing the current environment's wrapped, sops 'sopsw' values file."
  value       = var.create_local_sops_wrapper ? "${local_file.sopsw[0].filename} -e ${local.sopsw_parent_yaml_file_path}" : null
}
