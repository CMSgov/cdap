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
    Name        = local.repo_name
    Environment = var.platform.env
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
            description  = coalesce(rule.description, "Expire all tagged images older than ${rule.expiry_days} days")
            selection    = { tagStatus = "tagged", countType = "sinceImagePushed", countUnit = "days", countNumber = rule.expiry_days }
            action       = { type = "expire" }
            }) : jsonencode({
            rulePriority = idx + 1
            description  = coalesce(rule.description, "Keep last ${rule.retained_images} tagged images")
            selection    = { tagStatus = "tagged", countType = "imageCountMoreThan", countNumber = rule.retained_images }
            action       = { type = "expire" }
          })
        )
      ],

      # Untagged images rule — always appended last (lowest priority).
      # Exclusively controls untagged image cleanup — catch-all rules above
      # intentionally use tagStatus "tagged" to avoid pre-empting this rule.
      [
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
