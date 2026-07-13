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

      # Rules with an explicit tag prefix (tagStatus: tagged)
      [
        for idx, rule in var.tag_rules : {
          rulePriority = idx + 1
          description = rule.description != null ? rule.description : (
            coalesce(rule.count_type, "imageCountMoreThan") == "imageCountMoreThan"
            ? "Keep last ${rule.retained_images} images for tag prefix '${rule.tag_prefix}'"
            : "Expire images with tag prefix '${rule.tag_prefix}' older than ${rule.expiry_days} days"
          )
          selection = coalesce(rule.count_type, "imageCountMoreThan") == "sinceImagePushed" ? {
            tagStatus     = "tagged"
            tagPrefixList = [rule.tag_prefix]
            countType     = "sinceImagePushed"
            countUnit     = "days"
            countNumber   = rule.expiry_days
            } : {
            tagStatus     = "tagged"
            tagPrefixList = [rule.tag_prefix]
            countType     = "imageCountMoreThan"
            countNumber   = rule.retained_images
          }
          action = { type = "expire" }
        }
        if rule.tag_prefix != null
      ],

      # Catch-all rules (tagStatus: any) — no tagPrefixList
      [
        for idx, rule in var.tag_rules : {
          rulePriority = idx + 1
          description = rule.description != null ? rule.description : (
            coalesce(rule.count_type, "imageCountMoreThan") == "imageCountMoreThan"
            ? "Keep last ${rule.retained_images} images (all tags)"
            : "Expire all images older than ${rule.expiry_days} days"
          )
          selection = coalesce(rule.count_type, "imageCountMoreThan") == "sinceImagePushed" ? {
            tagStatus   = "any"
            countType   = "sinceImagePushed"
            countUnit   = "days"
            countNumber = rule.expiry_days
            } : {
            tagStatus   = "any"
            countType   = "imageCountMoreThan"
            countNumber = rule.retained_images
          }
          action = { type = "expire" }
        }
        if rule.tag_prefix == null
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
