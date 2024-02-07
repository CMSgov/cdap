packer {
  required_plugins {
    amazon = {
      version = ">= 1.3.0"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

build {
  name = "github-actions-runner"
  sources = [
    "source.amazon-ebs.github-actions-runner"
  ]

  provisioner "shell" {
    environment_vars = []
    inline = concat([
      "sudo yum -y upgrade-minimal",
      "sudo yum -y install amazon-cloudwatch-agent jq git docker",
      "sudo yum -y install curl",
      "sudo systemctl enable docker.service",
      "sudo systemctl enable containerd.service",
      "sudo service docker start",
      "sudo usermod -a -G docker ec2-user",
    ], var.custom_shell_commands)
  }


  provisioner "file" {
    content = templatefile("./install-runner.sh", {
      S3_LOCATION_RUNNER_DISTRIBUTION = var.s3_tarball
    })
    destination = "/tmp/install-runner.sh"
  }

  provisioner "shell" {
    inline = [
      "chmod +x /tmp/install-runner.sh",
      "/tmp/install-runner.sh"
    ]
  }

  provisioner "file" {
    content = templatefile("./start-runner.sh", { metadata_tags = "enabled" })
    destination = "/tmp/start-runner.sh"
  }

  provisioner "shell" {
    inline = [
      "sudo mv /tmp/start-runner.sh /var/lib/cloud/scripts/per-boot/start-runner.sh",
      "sudo chmod +x /var/lib/cloud/scripts/per-boot/start-runner.sh",
    ]
  }

  post-processor "manifest" {
    output     = "manifest.json"
    strip_path = true
  }
}
