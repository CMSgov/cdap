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
      # Tagged/catch-all rules — one per tag_rules entry, in priority order
      [
        for idx, rule in var.tag_rules : {
          rulePriority = idx + 1
          description = rule.description != null ? rule.description : (
            coalesce(rule.count_type, "imageCountMoreThan") == "imageCountMoreThan"
            ? "Keep last ${rule.retained_images} images${rule.tag_prefix != null ? " for tag prefix '${rule.tag_prefix}'" : ""}"
            : "Expire images${rule.tag_prefix != null ? " with tag prefix '${rule.tag_prefix}'" : ""} older than ${rule.expiry_days} days"
          )
          selection = merge(
            rule.tag_prefix != null
            ? { tagStatus = "tagged", tagPrefixList = [rule.tag_prefix] }
            : { tagStatus = "any" },
            coalesce(rule.count_type, "imageCountMoreThan") == "sinceImagePushed"
            ? { countType = "sinceImagePushed", countUnit = "days", countNumber = rule.expiry_days }
            : { countType = "imageCountMoreThan", countNumber = rule.retained_images }
          )
          action = { type = "expire" }
        }
      ],

      # Untagged images rule — always appended last (lowest priority)
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
