locals {
  service   = var.service != null ? var.service : var.platform.service
  repo_name = var.repo_name_override != null ? var.repo_name_override : "${var.platform.app}-${var.platform.env}-${local.service}"
}

resource "aws_ecr_repository" "this" {
  name                 = local.repo_name
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = false # Attestation ECR.1 permits this as false and coverage is achieved through Snyk
  }

  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = var.platform.kms_alias_primary.target_key_arn
  }

  tags = {
    Name = local.repo_name
  }
}

resource "aws_ecr_lifecycle_policy" "this" {
  repository = aws_ecr_repository.this.name

  policy = jsonencode({
    rules = concat(
      [
        for idx, rule in var.tag_rules :
        jsondecode(
          rule.tag_prefix != null && coalesce(rule.count_type, "imageCountMoreThan") == "sinceImagePushed" ? jsonencode({
            rulePriority = idx + 1
            description  = coalesce(rule.description, "Expire images with tag prefix '${rule.tag_prefix}' older than ${rule.expiry_days} days")
            selection    = { tagStatus = "tagged", tagPrefixList = [rule.tag_prefix], countType = "sinceImagePushed", countUnit = "days", countNumber = rule.expiry_days }
            action       = { type = "expire" }
            }) : rule.tag_prefix != null && coalesce(rule.count_type, "imageCountMoreThan") == "imageCountMoreThan" ? jsonencode({
            rulePriority = idx + 1
            description  = coalesce(rule.description, "Keep last ${rule.retained_images} images for tag prefix '${rule.tag_prefix}'")
            selection    = { tagStatus = "tagged", tagPrefixList = [rule.tag_prefix], countType = "imageCountMoreThan", countNumber = rule.retained_images }
            action       = { type = "expire" }
            }) : rule.tag_prefix == null && coalesce(rule.count_type, "imageCountMoreThan") == "sinceImagePushed" ? jsonencode({
            rulePriority = idx + 1
            description  = coalesce(rule.description, "Expire all images older than ${rule.expiry_days} days")
            selection    = { tagStatus = "any", countType = "sinceImagePushed", countUnit = "days", countNumber = rule.expiry_days }
            action       = { type = "expire" }
            }) : jsonencode({
            rulePriority = idx + 1
            description  = coalesce(rule.description, "Keep last ${rule.retained_images} images (all tags)")
            selection    = { tagStatus = "any", countType = "imageCountMoreThan", countNumber = rule.retained_images }
            action       = { type = "expire" }
          })
        )
      ],

      # Only append the explicit untagged rule if no catch-all "any" rule exists.
      # If a catch-all is present it already covers untagged images, and a
      # lower-priority untagged rule would be unreachable.
      anytrue([for rule in var.tag_rules : rule.tag_prefix == null]) ? [] : [
        {
          rulePriority = length(var.tag_rules) + 1
          description  = "Expire untagged images after ${var.untagged_expiry_days} days"
          selection = {
            tagStatus   = "untagged"
            countType   = "sinceImagePushed"
            countUnit   = "days"
            countNumber = var.untagged_expiry_days
          }
          action = { type = "expire" }
        }
      ]
    )
  })
}

resource "aws_ssm_parameter" "image_tag" {
  name = "/${var.platform.app}/${var.platform.env}/services/${local.service}/image_tag"
  type = "String"
  # Placeholder — will be overwritten by the build workflow on first push
  value = "initial"

  lifecycle {
    # Never let Tofu overwrite a real tag written by the workflow
    ignore_changes = [value]
  }
}

resource "aws_ssm_parameter" "image_version" {
  name  = "/${var.platform.app}/${var.platform.env}/services/${local.service}/image_version"
  type  = "String"
  value = "initial"

  lifecycle {
    ignore_changes = [value]
  }
}
