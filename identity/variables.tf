variable "region" {
  description = "AWS region for the resources this config's roles will be allowed to manage"
  type        = string
  default     = "eu-west-2"
}

variable "name_prefix" {
  description = "Must match local.name_prefix in the main terraform/ stack - used to build the fixed-name ARNs these roles are scoped to"
  type        = string
  default     = "gatus-ecs"
}

variable "github_repository" {
  description = "GitHub repo allowed to assume these roles, in org/repo format"
  type        = string
  default     = "AdanAbdillahi/ecs-gatus-project"
}

# GitHub's OIDC sub claim includes immutable owner/repo IDs once either has
# been renamed - "repo:OWNER@ownerId/REPO@repoId:..." instead of the plain
# name. These IDs don't change again.
variable "github_owner_id" {
  description = "Immutable numeric ID behind var.github_repository's owner - from the actual OIDC token's sub claim, not GitHub's UI"
  type        = string
  default     = "99089028"
}

variable "github_repo_id" {
  description = "Immutable numeric ID behind var.github_repository's repo name - from the actual OIDC token's sub claim, not GitHub's UI"
  type        = string
  default     = "1350685556"
}

variable "tf_state_bucket" {
  description = "S3 bucket holding both this config's state and the main stack's state"
  type        = string
  default     = "ecs-gatus-tfstate-533267395439"
}

variable "route53_zone_id" {
  description = "Existing hosted zone ID for the domain (aws_route53_zone.this in the main stack's r53/acm modules)"
  type        = string
  default     = "Z02906521H4NP7OMCMW5"
}
