# ECS Gatus Project

Production-style AWS deployment of [Gatus](https://github.com/TwiN/gatus), an
open-source uptime/status monitor, running on ECS Fargate behind an ALB. The
app is a config-driven Go binary with no database, so the project is about the
platform around it: networking, delivery, identity and security controls.

Live at `gatus.adanabdillahi.com`.

## Architecture

![Architecture diagram](docs/ECS%20Gatus%20Architecture.png)

- **Network**: VPC (`10.0.0.0/24`) across two AZs in `eu-west-2`, one public and one private subnet per AZ, single NAT gateway
- **Edge**: Route 53 alias record to the ALB. The ALB terminates HTTPS with a DNS-validated ACM certificate and redirects port 80 to 443
- **Compute**: ECS service on Fargate, 2 tasks (one per AZ) in private subnets with no public IP. Deployment circuit breaker with automatic rollback
- **Images**: ECR, tagged by git commit SHA. Each deploy registers a task definition revision pinned to one SHA
- **Logs**: CloudWatch Logs group `/ecs/gatus-ecs`
- **IaC**: Terraform, one module per concern (`vpc`, `sg`, `alb`, `acm`, `r53`, `ecr`, `ecs`), S3 remote state with native locking
- **Identity**: GitHub Actions authenticates with OIDC. No AWS keys are stored in GitHub

### Traffic

| Path | Route | Allowed by |
|---|---|---|
| User request | Route 53 → internet gateway → ALB → task on port 8080 | `alb_sg` in 80/443 from anywhere; `ecs_sg` in 8080 from `alb_sg` only |
| Health check | ALB → task `GET /health` | same as above |
| Task outbound | task → NAT gateway → internet gateway | `ecs_sg` out TCP 443 only (ECR pulls, log delivery, the HTTPS endpoints in `config.yaml`) |

The ALB's only outbound rule is the app port to `ecs_sg`.

## CI/CD

| Trigger | [`build-and-push.yml`](.github/workflows/build-and-push.yml) | [`terraform-infra.yml`](.github/workflows/terraform-infra.yml) |
|---|---|---|
| Pull request | build + Trivy scan, no AWS access | Checkov scan, `plan` |
| Push to `main` | build, scan, push `:<sha>`, deploy | Checkov scan, `plan` + `apply` |
| Path filter | `Dockerfile`, `config.yaml`, `.dockerignore`, `gatus` | `terraform/**` |

Both can also be started manually from the Actions tab.

**How an image gets deployed:**

1. Build the image and scan it with Trivy. A `CRITICAL` finding fails the job before anything is pushed.
2. Assume the deploy role through OIDC and push the image to ECR tagged with the commit SHA.
3. Copy the current task definition, set the new image, and register it as a new revision.
4. Point the ECS service at that revision and wait until the service is stable.
5. If the new tasks keep failing, the circuit breaker rolls the service back to the last working revision and the job fails.

Terraform creates the service and its first task definition, then ignores
`task_definition` changes, so a later `apply` never reverts a deploy.

## Identity and OIDC

[`identity/`](identity/) is a separate Terraform config with its own state. It
creates the GitHub OIDC provider and two roles, and is applied by hand, never
from CI.

| Role | Used by | Trusted from | Can do |
|---|---|---|---|
| `gatus-ecs-github-actions` | `build-and-push.yml` | `main` | Push to the one ECR repo, register task definitions, update the one ECS service, pass the execution role to ECS |
| `gatus-ecs-terraform-ci` | `terraform-infra.yml` | `main` and pull requests | Manage the resources in `terraform/`, read and write its state |

Keeping the roles out of `terraform/` means the pipeline that runs Terraform
can't change its own permissions, and destroying the app stack doesn't remove
the CI login. The cost is that permission changes need a manual apply of
`identity/`.

Trust policies match the repository by its immutable owner and repo IDs
(`repo:Owner@<id>/Repo@<id>:...`), since GitHub uses that form in the token
once a repository has been renamed.

## Repository layout

| Path | Contents |
|---|---|
| `Dockerfile`, `config.yaml`, `gatus/` | Application image. `gatus/` is a submodule pinned to a Gatus release; `config.yaml` lists the monitored endpoints |
| `terraform/` | App stack: VPC, security groups, ALB, ACM, Route 53, ECR, ECS |
| `identity/` | OIDC provider and CI roles. Own state, applied by hand |
| `.github/workflows/` | The two pipelines |
| `docs/` | Architecture diagram |

## Decisions

- **Fargate**: no instances to patch or scale for a two-task service.
- **TLS ends at the ALB**: traffic from the ALB to the tasks stays inside the VPC on the app port.
- **Single NAT gateway**: half the cost of one per AZ, at the price of a single-AZ dependency for outbound traffic.
- **SHA-pinned task definitions**: the running revision records exactly which build is live, and rollback means pointing the service at the previous revision.
- **Separate identity stack**: covered above.

## What I'd add next

- **Log retention**: the log group has no `retention_in_days`, so logs are kept forever.
- **Alarms**: CloudWatch alarms with SNS email for unhealthy targets and running tasks below desired. Nothing alerts today.
- **Health check grace period**: not set on the service, so slow-starting tasks can be marked unhealthy early.
- **Approval gate on apply**: a GitHub environment with a required reviewer. This changes the OIDC subject, so the Terraform role's trust policy needs updating first.
- **Checkov as a gate**: it runs in report-only mode. The remaining findings need fixing or skipping with a reason before it can block.
- **Trivy on `HIGH`**: the scan blocks only `CRITICAL` until the Go builder and Gatus dependencies are bumped.
- **VPC endpoints** for ECR, S3 and CloudWatch Logs, so tasks stop sending AWS traffic through the NAT gateway.
- **Fully immutable ECR tags**: `latest` is still excluded, only so the bootstrap task definition has an image to start from.
- **Remote state for `identity/`**: it currently uses local state.
- **IAM scoping**: a few actions on the Terraform role use `Resource: "*"` because AWS doesn't support resource-level permissions for them. Worth re-auditing before reusing the pattern in a shared account.
