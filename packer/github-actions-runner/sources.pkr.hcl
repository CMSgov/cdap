source "amazon-ebs" "github-actions-runner" {
  ami_name                                  = "github-actions-runner-${formatdate("YYYYMMDDhhmm", timestamp())}"
  instance_type                             = var.instance_type
  region                                    = var.region
  security_group_id                         = var.security_group_id
  subnet_id                                 = var.subnet_id
  associate_public_ip_address               = var.associate_public_ip_address
  temporary_security_group_source_public_ip = var.temporary_security_group_source_public_ip

  source_ami_filter {
    ami_filter = { name = ["${ vars.AMI_FILTER }"] }
    ami_owners = ["${ vars.AMI_ACCOUNT }"]
    enable_userdata = false
  }

  ssh_username = "ec2-user"
}
