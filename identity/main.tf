
data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id

  ecr_repository_arn              = "arn:aws:ecr:${var.region}:${local.account_id}:repository/${var.name_prefix}-ecr"
  ecs_cluster_arn                 = "arn:aws:ecs:${var.region}:${local.account_id}:cluster/${var.name_prefix}-cluster"
  ecs_service_arn                 = "arn:aws:ecs:${var.region}:${local.account_id}:service/${var.name_prefix}-cluster/${var.name_prefix}-service"
  ecs_task_definition_arn_pattern = "arn:aws:ecs:${var.region}:${local.account_id}:task-definition/${var.name_prefix}-task:*"
  ecs_execution_role_arn          = "arn:aws:iam::${local.account_id}:role/${var.name_prefix}-ecs-execution-role"
  # CW Logs ARN format is inconsistent - tagging wants the bare ARN,
  # everything else wants a trailing ":*". Cover both.
  cloudwatch_log_group_arns = [
    "arn:aws:logs:${var.region}:${local.account_id}:log-group:/ecs/${var.name_prefix}",
    "arn:aws:logs:${var.region}:${local.account_id}:log-group:/ecs/${var.name_prefix}:*",
  ]
  state_bucket_arn = "arn:aws:s3:::${var.tf_state_bucket}"
  # Native S3 locking also writes a "<key>.tflock" sibling object - needs
  # the same permissions as the state file itself.
  state_object_arns = [
    "arn:aws:s3:::${var.tf_state_bucket}/networking/terraform.tfstate",
    "arn:aws:s3:::${var.tf_state_bucket}/networking/terraform.tfstate.tflock",
  ]
  route53_zone_arn = "arn:aws:route53:::hostedzone/${var.route53_zone_id}"

  # Actual "repo:" segment from the OIDC sub claim - see var.github_owner_id
  github_sub_repo = "${split("/", var.github_repository)[0]}@${var.github_owner_id}/${split("/", var.github_repository)[1]}@${var.github_repo_id}"
}



data "tls_certificate" "github_oidc" {
  url = "https://token.actions.githubusercontent.com"
}

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.github_oidc.certificates[0].sha1_fingerprint]
}



data "aws_iam_policy_document" "github_actions_trust" {
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

      values = ["repo:${local.github_sub_repo}:ref:refs/heads/main"]
    }
  }
}

resource "aws_iam_role" "github_actions" {
  name               = "${var.name_prefix}-github-actions"
  assume_role_policy = data.aws_iam_policy_document.github_actions_trust.json

  tags = {
    Name = "${var.name_prefix}-github-actions"
  }
}

data "aws_iam_policy_document" "github_actions_permissions" {
  statement {
    sid       = "ECRAuth"
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid    = "ECRPush"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:PutImage",
    ]
    resources = [local.ecr_repository_arn]
  }

  statement {
    sid       = "ECSDeploy"
    effect    = "Allow"
    actions   = ["ecs:UpdateService"]
    resources = [local.ecs_service_arn]
  }
}

resource "aws_iam_role_policy" "github_actions" {
  name   = "${var.name_prefix}-github-actions-policy"
  role   = aws_iam_role.github_actions.id
  policy = data.aws_iam_policy_document.github_actions_permissions.json
}

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
      values = [
        "repo:${local.github_sub_repo}:ref:refs/heads/main",
        "repo:${local.github_sub_repo}:pull_request",
      ]
    }
  }
}

resource "aws_iam_role" "terraform_ci" {
  name               = "${var.name_prefix}-terraform-ci"
  assume_role_policy = data.aws_iam_policy_document.terraform_ci_trust.json

  tags = {
    Name = "${var.name_prefix}-terraform-ci"
  }
}

data "aws_iam_policy_document" "terraform_ci_permissions" {
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
    resources = [
      local.route53_zone_arn,
      "arn:aws:route53:::change/*",
    ]
  }

  statement {
    sid    = "Route53ListZones"
    effect = "Allow"
    actions = [
      "route53:ListHostedZones", "route53:ListHostedZonesByName",
    ]
    # List-all-zones calls - Route53 doesn't support scoping to one zone ARN
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
    resources = [
      local.ecs_cluster_arn,
      local.ecs_service_arn,
      local.ecs_task_definition_arn_pattern,
    ]
  }

  statement {
    sid    = "ECSList"
    effect = "Allow"
    actions = [
      "ecs:ListClusters", "ecs:ListServices", "ecs:ListTaskDefinitions",
      # Task definition actions don't support resource-level ARNs at all
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
    sid       = "Logs"
    effect    = "Allow"
    actions   = ["logs:CreateLogGroup", "logs:DeleteLogGroup", "logs:PutRetentionPolicy", "logs:TagResource", "logs:ListTagsForResource"]
    resources = local.cloudwatch_log_group_arns
  }

  statement {
    sid    = "LogsListGroups"
    effect = "Allow"
    actions = [
      "logs:DescribeLogGroups", # account-wide list call, can't scope to one log group ARN
    ]
    resources = ["*"]
  }

  statement {
    sid       = "TerraformStateObject"
    effect    = "Allow"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = local.state_object_arns
  }

  statement {
    sid       = "TerraformStateBucket"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [local.state_bucket_arn]

    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = ["networking/*"]
    }
  }


  statement {
    sid    = "ECSExecutionRoleOnly"
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
    sid       = "PassEcsExecutionRoleToECS"
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

resource "aws_iam_role_policy" "terraform_ci" {
  name   = "${var.name_prefix}-terraform-ci-policy"
  role   = aws_iam_role.terraform_ci.id
  policy = data.aws_iam_policy_document.terraform_ci_permissions.json
}
