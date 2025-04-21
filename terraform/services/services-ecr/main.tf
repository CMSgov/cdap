resource "aws_ecr_repository" "ab2d_${var.env}_services" {
  name                 = "ab2d-${var.env}-services"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = false
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name = "ab2d-${var.env}-services"
  }
}

resource "aws_ecr_lifecycle_policy" "ab2d_${var.env}_services_policy" {
  repository = aws_ecr_repository.ab2d_${var.env}_services.name
  policy     = file("${path.module}/ab2d-services-lifecycle-policy.json")
}
