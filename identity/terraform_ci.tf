# Second role for terraform-infra.yml. Same OIDC provider, own trust and permissions.

# Trust: main for apply, pull_request for plan
data "aws_iam_policy_document" "terraform_ci_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = var.terraform_ci_subjects
    }
  }
}

resource "aws_iam_role" "terraform_ci" {
  name               = var.terraform_ci_role_name
  assume_role_policy = data.aws_iam_policy_document.terraform_ci_trust.json
}

locals {
  ecs_execution_role_arn = "arn:aws:iam::${local.account_id}:role/${var.name_prefix}-ecs-execution-role"
  ecr_repository_arn     = "arn:aws:ecr:${var.aws_region}:${local.account_id}:repository/${var.ecr_repository_name}"
  route53_zone_arn       = "arn:aws:route53:::hostedzone/${var.route53_zone_id}"

  # Log group tagging wants the bare ARN, everything else the ":*" form
  log_group_arns = [
    "arn:aws:logs:${var.aws_region}:${local.account_id}:log-group:/ecs/${var.name_prefix}",
    "arn:aws:logs:${var.aws_region}:${local.account_id}:log-group:/ecs/${var.name_prefix}:*",
  ]

  ecs_arns = [
    "arn:aws:ecs:${var.aws_region}:${local.account_id}:cluster/${var.ecs_cluster_name}",
    "arn:aws:ecs:${var.aws_region}:${local.account_id}:service/${var.ecs_cluster_name}/${var.ecs_service_name}",
    "arn:aws:ecs:${var.aws_region}:${local.account_id}:task-definition/${var.name_prefix}-task:*",
  ]
}

# Permissions: what Terraform needs to manage the main stack
data "aws_iam_policy_document" "terraform_ci_permissions" {
  # State file and its .tflock sibling
  statement {
    sid     = "StateObject"
    effect  = "Allow"
    actions = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = [
      "arn:aws:s3:::${var.tf_state_bucket}/${var.tf_state_key}",
      "arn:aws:s3:::${var.tf_state_bucket}/${var.tf_state_key}.tflock",
    ]
  }

  statement {
    sid       = "StateBucket"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = ["arn:aws:s3:::${var.tf_state_bucket}"]
  }

  # VPC, subnets, routing, NAT, security groups (all ec2: actions, no resource scoping)
  statement {
    sid    = "EC2Networking"
    effect = "Allow"
    actions = [
      "ec2:Describe*",
      "ec2:CreateVpc", "ec2:DeleteVpc", "ec2:ModifyVpcAttribute",
      "ec2:CreateSubnet", "ec2:DeleteSubnet", "ec2:ModifySubnetAttribute",
      "ec2:CreateInternetGateway", "ec2:DeleteInternetGateway",
      "ec2:AttachInternetGateway", "ec2:DetachInternetGateway",
      "ec2:AllocateAddress", "ec2:ReleaseAddress",
      "ec2:CreateNatGateway", "ec2:DeleteNatGateway",
      "ec2:CreateRouteTable", "ec2:DeleteRouteTable",
      "ec2:CreateRoute", "ec2:DeleteRoute",
      "ec2:AssociateRouteTable", "ec2:DisassociateRouteTable", "ec2:ReplaceRouteTableAssociation",
      "ec2:CreateSecurityGroup", "ec2:DeleteSecurityGroup",
      "ec2:AuthorizeSecurityGroupIngress", "ec2:AuthorizeSecurityGroupEgress",
      "ec2:RevokeSecurityGroupIngress", "ec2:RevokeSecurityGroupEgress",
      "ec2:CreateTags", "ec2:DeleteTags",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "ELB"
    effect = "Allow"
    actions = [
      "elasticloadbalancing:Describe*",
      "elasticloadbalancing:CreateLoadBalancer", "elasticloadbalancing:DeleteLoadBalancer",
      "elasticloadbalancing:ModifyLoadBalancerAttributes",
      "elasticloadbalancing:CreateTargetGroup", "elasticloadbalancing:DeleteTargetGroup",
      "elasticloadbalancing:ModifyTargetGroup", "elasticloadbalancing:ModifyTargetGroupAttributes",
      "elasticloadbalancing:CreateListener", "elasticloadbalancing:DeleteListener", "elasticloadbalancing:ModifyListener",
      "elasticloadbalancing:AddTags", "elasticloadbalancing:RemoveTags",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "ACM"
    effect = "Allow"
    actions = [
      "acm:RequestCertificate", "acm:DescribeCertificate", "acm:DeleteCertificate", "acm:GetCertificate",
      "acm:AddTagsToCertificate", "acm:ListTagsForCertificate",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "Route53"
    effect = "Allow"
    actions = [
      "route53:GetHostedZone",
      "route53:ChangeResourceRecordSets",
      "route53:ListResourceRecordSets",
      "route53:ListTagsForResource",
      "route53:GetChange",
    ]
    resources = [local.route53_zone_arn, "arn:aws:route53:::change/*"]
  }

  # Zone lookups by name can't be scoped to one zone
  statement {
    sid       = "Route53ListZones"
    effect    = "Allow"
    actions   = ["route53:ListHostedZones", "route53:ListHostedZonesByName"]
    resources = ["*"]
  }

  statement {
    sid    = "ECS"
    effect = "Allow"
    actions = [
      "ecs:CreateCluster", "ecs:DeleteCluster", "ecs:DescribeClusters",
      "ecs:PutClusterCapacityProviders", "ecs:DescribeCapacityProviders",
      "ecs:CreateService", "ecs:UpdateService", "ecs:DeleteService", "ecs:DescribeServices",
      "ecs:TagResource", "ecs:ListTagsForResource",
    ]
    resources = local.ecs_arns
  }

  # Task definition and list actions don't support resource-level permissions
  statement {
    sid    = "ECSUnscoped"
    effect = "Allow"
    actions = [
      "ecs:ListClusters", "ecs:ListServices", "ecs:ListTaskDefinitions",
      "ecs:RegisterTaskDefinition", "ecs:DeregisterTaskDefinition", "ecs:DescribeTaskDefinition",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "ECR"
    effect = "Allow"
    actions = [
      "ecr:CreateRepository", "ecr:DeleteRepository", "ecr:DescribeRepositories",
      "ecr:PutLifecyclePolicy", "ecr:GetLifecyclePolicy", "ecr:DeleteLifecyclePolicy",
      "ecr:PutImageTagMutability", "ecr:PutImageScanningConfiguration",
      "ecr:TagResource", "ecr:ListTagsForResource",
    ]
    resources = [local.ecr_repository_arn]
  }

  statement {
    sid    = "Logs"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup", "logs:DeleteLogGroup", "logs:PutRetentionPolicy",
      "logs:TagResource", "logs:ListTagsForResource",
    ]
    resources = local.log_group_arns
  }

  # Account-wide list call, can't scope to one log group
  statement {
    sid       = "LogsList"
    effect    = "Allow"
    actions   = ["logs:DescribeLogGroups"]
    resources = ["*"]
  }

  # IAM only for the ECS execution role - never wider, or CI could grant itself admin
  statement {
    sid    = "ExecutionRoleOnly"
    effect = "Allow"
    actions = [
      "iam:CreateRole", "iam:DeleteRole", "iam:GetRole",
      "iam:PutRolePolicy", "iam:GetRolePolicy", "iam:DeleteRolePolicy",
      "iam:AttachRolePolicy", "iam:DetachRolePolicy",
      "iam:ListAttachedRolePolicies", "iam:ListRolePolicies",
      "iam:TagRole",
    ]
    resources = [local.ecs_execution_role_arn]
  }

  statement {
    sid       = "PassExecutionRoleToECS"
    effect    = "Allow"
    actions   = ["iam:PassRole"]
    resources = [local.ecs_execution_role_arn]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_policy" "terraform_ci" {
  name   = "${var.terraform_ci_role_name}-policy"
  policy = data.aws_iam_policy_document.terraform_ci_permissions.json
}

resource "aws_iam_role_policy_attachment" "terraform_ci" {
  role       = aws_iam_role.terraform_ci.name
  policy_arn = aws_iam_policy.terraform_ci.arn
}

output "terraform_ci_role_arn" {
  description = "Use as role-to-assume in terraform-infra.yml"
  value       = aws_iam_role.terraform_ci.arn
}
