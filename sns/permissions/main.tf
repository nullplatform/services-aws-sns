# An alias cannot be the Resource of an IAM statement: resolve it to the key ARN.
data "aws_kms_key" "topic" {
  count  = var.kms_key_id == "" ? 0 : 1
  key_id = var.kms_key_id
}

locals {
  # Must match specs/requirements/aws: the permissions role may only create link users under this
  # path, and only with this boundary, which caps them at the topic actions below.
  link_iam_path     = "/nullplatform/sns/"
  link_boundary_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy${local.link_iam_path}np-sns-link-boundary"
}

data "aws_caller_identity" "current" {}

resource "aws_iam_user" "link" {
  name                 = var.user_name
  path                 = local.link_iam_path
  permissions_boundary = local.link_boundary_arn

  tags = {
    "managed-by" = "nullplatform"
    "link-id"    = var.link_id
  }
}

resource "aws_iam_user_policy" "link" {
  name = "${var.user_name}-topic"
  user = aws_iam_user.link.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [
        {
          # SNS authorizes the subscription actions against the topic ARN, not the subscription's.
          Sid    = "UseTopic"
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
          Resource = var.topic_arn
        },
      ],
      var.kms_key_id == "" ? [] : [{
        Sid      = "UseTopicKey"
        Effect   = "Allow"
        Action   = ["kms:GenerateDataKey*", "kms:Decrypt"]
        Resource = data.aws_kms_key.topic[0].arn
      }],
    )
  })
}

resource "aws_iam_access_key" "link" {
  user = aws_iam_user.link.name
}
