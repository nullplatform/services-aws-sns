locals {
  iam_module_name = "requirements-sns"

  iam_create = var.iam_create_role

  role_name            = var.role_name != "" ? var.role_name : "nullplatform_${var.cluster_name}_sns_role"
  policies_name_prefix = var.policies_name_prefix != "" ? var.policies_name_prefix : "nullplatform_${var.cluster_name}"

  account_id = data.aws_caller_identity.current.account_id

  agent_role_arn = var.agent_role_arn != "" ? var.agent_role_arn : "arn:aws:iam::${local.account_id}:role/nullplatform-${var.cluster_name}-agent-role"

  logging_roles_arn = "arn:aws:iam::${local.account_id}:role/${var.resource_name_prefix}sns-logs-*"

  iam_default_tags = merge(var.iam_resource_tags_json, {
    ManagedBy = "nullplatform-custom-scope-role"
    Module    = local.iam_module_name
  })

  policy_documents = {
    topics = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Sid      = "ManageTopics"
          Effect   = "Allow"
          Action   = ["sns:*"]
          Resource = "arn:aws:sns:*:${local.account_id}:${var.resource_name_prefix}*"
        },
        {
          Sid      = "AccountLevelReads"
          Effect   = "Allow"
          Action   = ["sns:ListTopics"]
          Resource = "*"
        },
      ]
    })

    link_users = jsonencode({
      Version = "2012-10-17"
      Statement = [{
        Sid    = "ManageLinkUsers"
        Effect = "Allow"
        Action = [
          "iam:CreateUser",
          "iam:DeleteUser",
          "iam:GetUser",
          "iam:TagUser",
          "iam:UntagUser",
          "iam:ListUserTags",
          "iam:PutUserPolicy",
          "iam:GetUserPolicy",
          "iam:DeleteUserPolicy",
          "iam:ListUserPolicies",
          "iam:ListAttachedUserPolicies",
          "iam:ListGroupsForUser",
          "iam:CreateAccessKey",
          "iam:DeleteAccessKey",
          "iam:ListAccessKeys",
        ]
        Resource = "arn:aws:iam::${local.account_id}:user/${var.resource_name_prefix}*"
      }]
    })

    # Delivery status logging: the role the service creates for a topic, and handing that role
    # (or one the developer names) to SNS.
    delivery_logging = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Sid    = "ManageLoggingRoles"
          Effect = "Allow"
          Action = [
            "iam:CreateRole",
            "iam:DeleteRole",
            "iam:GetRole",
            "iam:TagRole",
            "iam:UntagRole",
            "iam:ListRoleTags",
            "iam:UpdateRoleDescription",
            "iam:UpdateAssumeRolePolicy",
            "iam:PutRolePolicy",
            "iam:GetRolePolicy",
            "iam:DeleteRolePolicy",
            "iam:ListRolePolicies",
            "iam:ListAttachedRolePolicies",
            "iam:ListInstanceProfilesForRole",
          ]
          Resource = local.logging_roles_arn
        },
        {
          Sid       = "PassLoggingRolesToSns"
          Effect    = "Allow"
          Action    = ["iam:PassRole"]
          Resource  = distinct(concat([local.logging_roles_arn], var.delivery_logging_role_arns))
          Condition = { StringEquals = { "iam:PassedToService" = "sns.amazonaws.com" } }
        },
      ]
    })

    kms = jsonencode({
      Version = "2012-10-17"
      Statement = [{
        Sid      = "UseTopicKeys"
        Effect   = "Allow"
        Action   = ["kms:DescribeKey", "kms:GenerateDataKey", "kms:Decrypt"]
        Resource = var.kms_key_arns
      }]
    })

    state = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          # No prefix condition on purpose: HeadBucket (build_context) sends no prefix, and the
          # S3 backend lists env:/ to find workspaces. Object access below stays under services/sns/.
          Sid      = "ListStateBucket"
          Effect   = "Allow"
          Action   = ["s3:ListBucket", "s3:ListBucketVersions", "s3:GetBucketLocation"]
          Resource = "arn:aws:s3:::${var.state_bucket_name}"
        },
        {
          Sid    = "ManageStateObjects"
          Effect = "Allow"
          Action = [
            "s3:GetObject",
            "s3:GetObjectVersion",
            "s3:PutObject",
            "s3:DeleteObject",
            "s3:DeleteObjectVersion",
          ]
          Resource = "arn:aws:s3:::${var.state_bucket_name}/services/sns/*"
        },
      ]
    })
  }
}
