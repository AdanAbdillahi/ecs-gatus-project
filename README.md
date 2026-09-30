# ECS Gatus Project

A production-style deployment of [Gatus](https://github.com/TwiN/gatus), an
open-source uptime/status monitor, on **AWS ECS Fargate**. The app is
deliberately simple (a config-driven Go binary, no admin UI, no database) so
the effort goes into the platform around it, not the app itself.

## Architecture

```
Route 53 (adanabdillahi.com)
        │
        ▼
   ACM cert (DNS-validated)
        │
        ▼
   ALB (public subnets, HTTPS)
        │
        ▼
   ECS Fargate service (private subnets, 2 tasks)
        │
        ▼
   ECR (gatus-ecs-ecr)
```

- **Network:** custom VPC, public + private subnets across 2 AZs, single NAT gateway
- **Edge:** Route 53 → ACM → Application Load Balancer, HTTPS only
- **Compute:** ECS Fargate, task definition always deploys the ECR `:latest` tag
- **Images:** ECR, SHA tags kept immutable forever (audit trail), `:latest` is the one movable tag the task definition references
- **IaC:** Terraform, modular (`vpc`, `sg`, `alb`, `acm`, `r53`, `ecr`, `ecs`), remote state in S3 with native S3 locking
- **CI/CD:** two independent GitHub Actions pipelines, both authenticating via OIDC — no long-lived AWS keys anywhere

## Repo layout

| Path | What it is |
|---|---|
| `Dockerfile`, `config.yaml`, `gatus/` (submodule) | The application image |
| `terraform/` | The app/infra stack — VPC, ALB, ACM, Route 53, ECS, ECR |
| `identity/` | A **separate, standalone** Terraform config — GitHub OIDC provider + the two CI roles. Own state, applied by hand only. See [Issues I Faced](#issues-i-faced) for why this isn't just another module in `terraform/` |
| `.github/workflows/build-and-push.yml` | Build → scan → push image → roll out |
| `.github/workflows/terraform-infra.yml` | `fmt` → `validate` → `plan` (PR comment) → `apply` |

## CI/CD

Two pipelines, deliberately independent — neither one needs to know what
the other last did:

```
                image build            infra apply
                    │                       │
   PR:            build+scan            plan (read-only)
                    │                       │
   ────────────── merge to main ────────────
                    │                       │
   main:   build → tag → push :sha+:latest  apply (vpc/alb/ecs/ecr)
                    │
             ecs update-service --force-new-deployment
```

That split only works cleanly because the ECS task definition always points
at the `:latest` tag — see the first entry below for why, and the
trade-off that came with it.

## Issues I Faced

Real problems hit while building this, and how they were resolved.

### 1. Coordinating two CI pipelines meant coupling them to a moving image tag

Splitting "build & push the image" from "apply Terraform" only works if
neither pipeline needs information from the other. With the original design
— SHA-tagged images, ECS task definition referencing a specific
`var.image_tag` passed in at `terraform apply` time — the infra pipeline
would need to learn which SHA the build pipeline had most recently pushed
(`workflow_run`, `repository_dispatch`, or a shared parameter store value).
That's real coordination machinery for a problem a solo project doesn't
need yet.

**Fix:** ECS now always deploys the ECR `:latest` tag. SHA tags still exist
permanently (ECR mutability scoped so they can never be overwritten) —
that's the audit trail and the manual-rollback path. `:latest` is the one
tag carved out as mutable via an
[`image_tag_mutability_exclusion_filter`](terraform/modules/ecr/main.tf),
which is what let the repository stay `IMMUTABLE` for everything else. The
trade-off: the task definition revision no longer proves which commit is
running — that's now read from ECS's own deployment history, or from the
SHA tag's push timestamp in ECR, instead.

**Gotcha along the way:** the exclusion filter attribute only works when
`image_tag_mutability` is set to `IMMUTABLE_WITH_EXCLUSION` — the plain
`IMMUTABLE` value rejects it outright. Caught by `terraform plan`, not by
reading the docs first.

### 2. Giving the Terraform CI role IAM permissions gave it permission over itself

The Terraform-apply pipeline needs to manage the ECS execution role (create
it, attach policies to it) as part of standing up the ECS service. But the
same module that creates CI roles (`github-oidc`) also creates *this* CI
role and the GitHub OIDC provider it trusts. A role that's allowed to edit
IAM roles and their trust policies can, in principle, rewrite its own
policy — a role meant to be scoped to "manage ECS infra" could quietly
become "manage anything," regardless of how carefully the policy document
was written.

**Fix:** the OIDC provider and both CI roles were pulled out of
`terraform/modules/github-oidc` entirely, into [`identity/`](identity/) — a
standalone Terraform config with **its own state file** (a different S3 key
in the same bucket), applied by hand from a personal AWS identity, never
from CI. That's what actually closes the gap: the Terraform-CI role only
ever runs against the main stack's state key, so the OIDC provider and both
roles simply don't exist in any state it can reach — there's nothing to
`apply` against, independent of how the IAM policy itself is worded. The
policy is additionally scoped by ARN to one deliberate exception (the ECS
execution role only), so even a mistake in the policy document can't reach
the identity layer.

### 3. A malformed IAM policy document that `terraform validate` would have caught immediately

While rewriting the CI role's permissions, found a pre-existing bug in the
old `github-oidc` module: one `statement` block (`ECRAuth`) was missing its
closing brace, so the next two `statement` blocks (`ECRPush`, `ECSDeploy`)
were silently nested *inside* it instead of being siblings. Valid-looking
HCL, invalid policy document — this would have failed on the very first
`terraform validate` run, before the module had ever been applied.

**Fix:** closed the brace, then made a habit of running `terraform fmt
-check` and `terraform validate` locally before treating any Terraform
change as done — both are now the first two steps of the `terraform-infra`
pipeline itself, so this class of bug fails fast in CI too.

### 4. GitHub's OIDC `sub` claim doesn't always match `owner/repo`

The IAM trust policy for both CI roles initially matched on
`repo:AdanAbdillahi/ecs-gatus-project:...`, the format shown in every GitHub
OIDC example. Both roles failed to assume with `Not authorized to perform
sts:AssumeRoleWithWebIdentity` despite the policy looking correct. Decoding
the actual token showed the real `sub` claim was
`repo:AdanAbdillahi@99089028/ecs-gatus-project@1350685556:ref:refs/heads/main`
— GitHub appends the immutable numeric owner/repo IDs once either has ever
been renamed, specifically so a freed-up old name can't be reused to forge
the same trust.

**Fix:** pinned the trust condition to the actual `owner@id/repo@id` form
instead of the plain name — more precise than wildcarding the name back
open, and the IDs don't change again even through future renames.

### 5. Dockerfile: Alpine vs Debian, and static linking

Documented in full in `CONTEXT.md`, summarized here: pinning the Go builder
image by digest initially broke the build with "apk not found" — the
digest resolved to a Debian-based tag, not the Alpine one the `deps` stage's
`apk` commands expected. Separately, the compiled binary failed to run on
the Alpine-based final image with a misleading `no such file or directory`
error — it was dynamically linked against glibc, which doesn't exist on
Alpine's musl libc. Fixed by pinning the correct Alpine-tagged digest and
building with `CGO_ENABLED=0` for a static binary.

## Not yet done

- `terraform apply` in `identity/` hasn't been run yet — the CI roles this
  README describes don't exist in AWS until that happens, by hand, once.
- The Terraform CI role's IAM permissions are broad (VPC/ALB/ACM/Route
  53/ECS/ECR) since this is a from-scratch environment; several of those
  grants use `resources = "*"` where the AWS service doesn't support
  resource-level scoping on create actions — normal for this kind of role,
  but worth a second look before this pattern is reused on an account with
  other things running in it.
