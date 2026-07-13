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
    rules = [
      {
        rulePriority = 1
        description  = "Keep last ${var.default_retained_images} images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = var.default_retained_images
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Keep last ${var.untagged_images_retained} untagged images"
        selection = {
          tagStatus   = "untagged"
          countType   = "imageCountMoreThan"
          countNumber = var.untagged_images_retained
        }
        action = { type = "expire" }
      }
    ]
  })
}
