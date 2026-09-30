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

# GitHub's OIDC "sub" claim is normally "repo:OWNER/REPO:...", but once an
# owner or repo has ever been renamed, GitHub appends the immutable numeric
# ID to each segment instead - "repo:OWNER@ownerId/REPO@repoId:..." - so
# that registering the old, now-available name can't forge the same trust.
# Confirmed by decoding the actual token in a debug CI run (see README /
# CONTEXT.md, "OIDC sub claim included immutable IDs"); these two IDs don't
# change even if the name changes again.
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
