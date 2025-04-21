
resource "aws_ecr_repository" "ab2d_worker" {
  name                 = "ab2d_worker"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = false
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name = "ab2d_worker"
  }
}

resource "aws_ecr_repository" "ab2d_api" {
  name                 = "ab2d_api"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name = "ab2d_api"
  }
}


resource "aws_ecr_lifecycle_policy" "ab2d_shared_policy" {
  repository = aws_ecr_repository.ab2d_worker.name
  policy     = file("${path.module}/ab2d-ecr-lifecycle-policy.json")
}

resource "aws_ecr_lifecycle_policy" "ab2d_api_policy" {
  repository = aws_ecr_repository.ab2d_api.name
  policy     = aws_ecr_lifecycle_policy.ab2d_shared_policy.policy
}
