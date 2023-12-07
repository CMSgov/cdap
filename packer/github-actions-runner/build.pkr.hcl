packer {
  required_plugins {
    amazon = {
      version = ">= 0.0.2"
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
    content = templatefile("../install-runner.sh", {
      ARM_PATCH                       = ""
      S3_LOCATION_RUNNER_DISTRIBUTION = ""
      RUNNER_ARCHITECTURE             = "x64"
    })
    destination = "/tmp/install-runner.sh"
  }

  provisioner "shell" {
    environment_vars = [
      "RUNNER_TARBALL_URL=https://github.com/actions/runner/releases/download/v${local.runner_version}/actions-runner-linux-x64-${local.runner_version}.tar.gz"
    ]
    inline = [
      "sudo chmod +x /tmp/install-runner.sh",
      "echo ec2-user > /tmp/install-user.txt",
      "sudo RUNNER_ARCHITECTURE=x64 RUNNER_TARBALL_URL=$RUNNER_TARBALL_URL /tmp/install-runner.sh"
    ]
  }

  post-processor "manifest" {
    output     = "manifest.json"
    strip_path = true
  }
}
