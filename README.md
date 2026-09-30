# ECS Gatus Project

Production-style AWS deployment of [Gatus](https://github.com/TwiN/gatus), an
open-source uptime/status monitor, running on ECS Fargate behind an ALB. The
application is intentionally simple — a config-driven Go binary with no
database — so the project focuses on the platform, not the app.

**Status:** live at `gatus.adanabdillahi.com`. Both pipelines are green.

## Architecture

```
Route 53  →  ACM (HTTPS)  →  ALB  →  ECS Fargate  →  ECR
              public subnets      private subnets
```

- **Network** — VPC across 2 AZs, public/private subnet split, single NAT gateway
- **Edge** — ALB terminates HTTPS with a DNS-validated ACM certificate; Route 53 alias record points at the ALB
- **Compute** — ECS Fargate service, 2 tasks, task definition always references the ECR `:latest` tag
- **Images** — ECR; SHA tags are immutable (permanent build history), `:latest` is the one mutable tag the service deploys
- **IaC** — Terraform, one module per concern (`vpc`, `sg`, `alb`, `acm`, `r53`, `ecr`, `ecs`), S3 remote state with native locking
- **Identity** — GitHub OIDC provider and both CI roles are managed in a separate Terraform state ([`identity/`](identity/)), applied independently of the app stack — no long-lived AWS keys anywhere

## CI/CD

| Trigger | [`build-and-push.yml`](.github/workflows/build-and-push.yml) | [`terraform-infra.yml`](.github/workflows/terraform-infra.yml) |
|---|---|---|
| Pull request | build + vulnerability scan | `plan`, posted as a PR comment |
| Push to `main` | build, scan, push `:sha` + `:latest`, force-deploy | `plan` + `apply` |

The two pipelines don't share any state or coordinate a tag between runs —
ECS always deploys `:latest`, so an infra change never depends on knowing
which commit's image is currently running, and vice versa.

## Repository layout

| Path | Contents |
|---|---|
| `Dockerfile`, `config.yaml`, `gatus/` | Application image (submodule pinned to a Gatus release) |
| `terraform/` | App/infra stack — VPC, ALB, ACM, Route 53, ECS, ECR |
| `identity/` | Standalone Terraform config — OIDC provider, CI roles. Own state, applied by hand |
| `.github/workflows/` | The two pipelines above |

## Things I'd change next time

- **Deployment circuit breaker** — not enabled on the ECS service; a bad
  deploy doesn't auto-rollback, it just keeps retrying.
- **Single NAT gateway** — pinned to one AZ. If that AZ has an issue, the
  private subnet in the other AZ loses outbound internet access too.
- **VPC endpoints** — ECR pulls and log shipping go over the NAT gateway
  instead of the AWS backbone, which costs more at any real volume.
- **Log retention** — the ECS log group has no `retention_in_days` set, so
  logs are kept forever by default.
- **CloudWatch alarms / alerting** — nothing pages on an unhealthy service
  or a failed deploy; it has to be checked manually.
- The image scan gates only on `CRITICAL` findings right now; `HIGH`
  findings are reported but non-blocking pending a dependency bump.
- The Terraform CI role's IAM policy uses `Resource: "*"` for a handful of
  actions where the AWS API itself doesn't support resource-level scoping —
  expected for this kind of role, worth re-auditing before reusing the
  pattern on an account running other workloads.
