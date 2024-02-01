source "amazon-ebs" "github-actions-runner" {
  ami_name                                  = "github-actions-runner-${formatdate("YYYYMMDDhhmm", timestamp())}"
  instance_type                             = var.instance_type
  region                                    = var.region
  security_group_id                         = var.security_group_id
  vpc_id                                    = var.vpc_id
  subnet_id                                 = var.subnet_id
  associate_public_ip_address               = var.associate_public_ip_address
  temporary_security_group_source_public_ip = var.temporary_security_group_source_public_ip
  iam_instance_profile                      = "bcda-mgmt-github-actions-deploy"

  source_ami_filter {
    filters = { name = "${var.ami_filter}" }
    owners = ["${var.ami_account}"]
    most_recent = true
  }

  security_group_filter {
    filters = {
      "tag:Name": "packer_sg"
    }
  }

  communicator = "ssh"
  ssh_username = "ec2-user"
  ssh_timeout = "1h"
  ssh_pty = true

  tags = {
    Name = "github-actions-runner-ami",
    Base_AMI_Name = "{{ .SourceAMIName }}"
  }
}
