locals {
  repos = [
    "api",
    "billing-api",
    "execucao-api",
    "charts/wrench-api",
    "charts/wrench-billing",
    "charts/wrench-execucao",
    "charts/structurizr",
  ]
}

resource "aws_ecr_repository" "wrench_repo" {
  for_each = toset(local.repos)

  name                 = "wrench/${each.value}"
  image_tag_mutability = "IMMUTABLE_WITH_EXCLUSION"
  force_delete         = true

  image_tag_mutability_exclusion_filter {
    filter      = "latest*"
    filter_type = "WILDCARD"
  }

  image_tag_mutability_exclusion_filter {
    filter      = "alpine*"
    filter_type = "WILDCARD"
  }

  image_tag_mutability_exclusion_filter {
    filter      = "dev-*"
    filter_type = "WILDCARD"
  }

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = var.main_tags
}