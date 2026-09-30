resource "aws_ecr_repository" "this" {
  name                 = "${var.name_prefix}-ecr"
  image_tag_mutability = "IMMUTABLE_WITH_EXCLUSION"

  # SHA tags stay immutable (never overwritten). "latest" is carved out as
  # the one movable tag so the ECS task definition can reference it without
  # Terraform needing to know which SHA was last built.
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
        # Evaluated first: claims the "latest" tag so rule 2 never counts it
        # towards the last-10 limit and can't expire it.
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
        # Everything else (the permanent SHA-tagged history) - keep only
        # the last 10 so storage doesn't grow forever.
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
