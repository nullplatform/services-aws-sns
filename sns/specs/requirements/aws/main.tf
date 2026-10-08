resource "aws_iam_role" "nullplatform_sns" {
  count = local.iam_create ? 1 : 0

  name        = local.role_name
  description = "Permissions role assumed by the nullplatform agent role for the aws-sns service"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { AWS = concat([local.agent_role_arn], var.additional_agent_role_arns) }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = local.iam_default_tags
}

resource "aws_iam_policy" "this" {
  for_each = local.iam_create ? local.policy_documents : {}

  name        = "${local.policies_name_prefix}_sns_${each.key}_policy"
  description = "${each.key} permissions for the nullplatform aws-sns service"
  policy      = each.value

  tags = local.iam_default_tags
}

resource "aws_iam_role_policy_attachment" "this" {
  for_each = aws_iam_policy.this

  role       = aws_iam_role.nullplatform_sns[0].name
  policy_arn = each.value.arn
}

# Caps every link IAM user at the topic actions its link policy grants: the permissions role may
# only create link users that carry it, so it cannot hand out broader access through their inline
# policies.
resource "aws_iam_policy" "link_boundary" {
  count = local.iam_create ? 1 : 0

  name        = local.link_boundary_name
  path        = local.link_iam_path
  description = "Permissions boundary of the IAM users created for links to nullplatform aws-sns topics"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # SNS authorizes the subscription actions against the topic ARN, so the topic pattern covers them.
        Sid    = "UseTopics"
        Effect = "Allow"
        Action = [
          "sns:Publish",
          "sns:Subscribe",
          "sns:ConfirmSubscription",
          "sns:GetTopicAttributes",
          "sns:ListSubscriptionsByTopic",
          "sns:Unsubscribe",
          "sns:GetSubscriptionAttributes",
          "sns:SetSubscriptionAttributes",
        ]
        Resource = "arn:aws:sns:*:${local.account_id}:${var.resource_name_prefix}*"
      },
      {
        # Publishing to an encrypted topic: SNS uses the key on the publisher's behalf.
        Sid      = "UseTopicKeysThroughSns"
        Effect   = "Allow"
        Action   = ["kms:GenerateDataKey*", "kms:Decrypt"]
        Resource = "*"
        Condition = {
          StringLike = { "kms:ViaService" = "sns.*.amazonaws.com" }
        }
      },
    ]
  })

  tags = local.iam_default_tags
}
