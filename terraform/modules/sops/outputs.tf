output "sopsw" {
  value = var.create_local_sops_wrapper ? "${local_file.sopsw[0].filename} -e ${local.sopsw_parent_yaml_file_path}" : null
}
