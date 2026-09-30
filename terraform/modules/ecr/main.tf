resource "aws_ecr_repository" "this" {
  name                 = "${var.name_prefix}-ecr"
  image_tag_mutability = "IMMUTABLE_WITH_EXCLUSION"

  # SHA tags stay immutable; "latest" is the one movable tag
  image_tag_mutability_exclusion_filter {
    filter      = "latest"
    filter_type = "WILDCARD"
  }

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_lifecycle_policy" "this" {
  repository = aws_ecr_repository.this.name

  policy = jsonencode({
    rules = [
      {
        # Runs first so rule 2 below never counts/expires this tag
        rulePriority = 1
        description  = "Never expire the latest tag"
        selection = {
          tagStatus      = "tagged"
          tagPatternList = ["latest"]
          countType      = "imageCountMoreThan"
          countNumber    = 999999
        }
        action = {
          type = "expire"
        }
      },
      {
        # Keep last 10 SHA-tagged images
        rulePriority = 2
        description  = "Keep only the last 10 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
