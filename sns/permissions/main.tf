# An alias cannot be the Resource of an IAM statement: resolve it to the key ARN.
data "aws_kms_key" "topic" {
  count  = var.kms_key_id == "" ? 0 : 1
  key_id = var.kms_key_id
}

resource "aws_iam_user" "link" {
  name = var.user_name

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
          Sid    = "UseTopic"
          Effect = "Allow"
          Action = [
            "sns:Publish",
            "sns:Subscribe",
            "sns:ConfirmSubscription",
            "sns:GetTopicAttributes",
            "sns:ListSubscriptionsByTopic",
          ]
          Resource = var.topic_arn
        },
        {
          # Subscription ARNs are <topic arn>:<subscription id>.
          Sid    = "ManageOwnSubscriptions"
          Effect = "Allow"
          Action = [
            "sns:Unsubscribe",
            "sns:GetSubscriptionAttributes",
            "sns:SetSubscriptionAttributes",
          ]
          Resource = "${var.topic_arn}:*"
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
