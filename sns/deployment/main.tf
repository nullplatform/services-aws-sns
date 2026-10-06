data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

locals {
  common_tags = merge(var.tags, {
    "managed-by" = "nullplatform"
    "service-id" = var.service_id
  })

  account_id      = data.aws_caller_identity.current.account_id
  owner_principal = "arn:${data.aws_partition.current.partition}:iam::${local.account_id}:root"

  # Delivery status logging: one role pair for every selected protocol.
  logging_enabled     = length(var.delivery_logging_protocols) > 0
  create_logging_role = local.logging_enabled && var.delivery_logging_roles == "create"
  success_role_arn    = local.create_logging_role ? aws_iam_role.delivery_logging[0].arn : var.delivery_logging_success_role_arn
  failure_role_arn    = local.create_logging_role ? aws_iam_role.delivery_logging[0].arn : var.delivery_logging_failure_role_arn
  logs = {
    for protocol in ["lambda", "sqs", "http", "application", "firehose"] :
    protocol => contains(var.delivery_logging_protocols, protocol)
  }

  owner_actions = [
    "SNS:GetTopicAttributes",
    "SNS:SetTopicAttributes",
    "SNS:AddPermission",
    "SNS:RemovePermission",
    "SNS:DeleteTopic",
    "SNS:Subscribe",
    "SNS:ListSubscriptionsByTopic",
    "SNS:Publish",
  ]
  subscribe_actions = ["SNS:Subscribe", "SNS:Receive"]

  basic_policy = {
    Version = "2012-10-17"
    Statement = concat(
      [{
        Sid       = "TopicOwner"
        Effect    = "Allow"
        Principal = { AWS = local.owner_principal }
        Action    = local.owner_actions
        Resource  = aws_sns_topic.topic.arn
      }],
      var.publishers == "everyone" ? [{
        Sid       = "PublishEveryone"
        Effect    = "Allow"
        Principal = { AWS = "*" }
        Action    = "SNS:Publish"
        Resource  = aws_sns_topic.topic.arn
      }] : [],
      var.publishers == "accounts" ? [{
        Sid       = "PublishAccounts"
        Effect    = "Allow"
        Principal = { AWS = var.publisher_principals }
        Action    = "SNS:Publish"
        Resource  = aws_sns_topic.topic.arn
      }] : [],
      var.subscribers == "everyone" ? [{
        Sid       = "SubscribeEveryone"
        Effect    = "Allow"
        Principal = { AWS = "*" }
        Action    = local.subscribe_actions
        Resource  = aws_sns_topic.topic.arn
      }] : [],
      var.subscribers == "accounts" ? [{
        Sid       = "SubscribeAccounts"
        Effect    = "Allow"
        Principal = { AWS = var.subscriber_principals }
        Action    = local.subscribe_actions
        Resource  = aws_sns_topic.topic.arn
      }] : [],
      var.subscribers == "endpoints" ? [{
        Sid       = "SubscribeEndpoints"
        Effect    = "Allow"
        Principal = { AWS = "*" }
        Action    = local.subscribe_actions
        Resource  = aws_sns_topic.topic.arn
        Condition = { StringLike = { "SNS:Endpoint" = var.subscriber_endpoints } }
      }] : [],
    )
  }

  # An advanced policy may write {{topic_arn}} where the topic ARN goes, or leave Resource empty
  # or out: the ARN is not known in the form before the topic exists.
  advanced_policy = jsondecode(var.access_policy_method == "advanced" ? replace(var.access_policy_json, "{{topic_arn}}", aws_sns_topic.topic.arn) : "{\"Statement\":[]}")
  advanced_statements = [
    for s in flatten([local.advanced_policy.Statement]) :
    merge(s, { Resource = try(s.Resource, "") == "" ? aws_sns_topic.topic.arn : s.Resource })
  ]

  topic_policy = var.access_policy_method == "advanced" ? jsonencode(merge(local.advanced_policy, { Statement = local.advanced_statements })) : jsonencode(local.basic_policy)
}

resource "aws_sns_topic" "topic" {
  name       = var.topic_name
  fifo_topic = var.fifo

  display_name         = var.display_name == "" ? null : var.display_name
  maximum_message_size = var.max_message_size_bytes
  kms_master_key_id    = var.kms_key_id == "" ? null : var.kms_key_id
  tracing_config       = var.active_tracing ? "Active" : "PassThrough"

  content_based_deduplication = var.fifo ? var.content_based_deduplication : null
  fifo_throughput_scope       = var.fifo ? var.fifo_throughput_scope : null
  # SNS rejects an empty ArchivePolicy: a FIFO topic turns its archive off with "{}".
  archive_policy = var.fifo ? (var.archive_retention_days > 0 ? jsonencode({ MessageRetentionPeriod = var.archive_retention_days }) : "{}") : null

  delivery_policy = var.delivery_policy_json == "" ? null : var.delivery_policy_json

  lambda_success_feedback_role_arn    = local.logs.lambda ? local.success_role_arn : null
  lambda_failure_feedback_role_arn    = local.logs.lambda ? local.failure_role_arn : null
  lambda_success_feedback_sample_rate = local.logs.lambda ? var.delivery_logging_sample_rate : null

  sqs_success_feedback_role_arn    = local.logs.sqs ? local.success_role_arn : null
  sqs_failure_feedback_role_arn    = local.logs.sqs ? local.failure_role_arn : null
  sqs_success_feedback_sample_rate = local.logs.sqs ? var.delivery_logging_sample_rate : null

  http_success_feedback_role_arn    = local.logs.http ? local.success_role_arn : null
  http_failure_feedback_role_arn    = local.logs.http ? local.failure_role_arn : null
  http_success_feedback_sample_rate = local.logs.http ? var.delivery_logging_sample_rate : null

  application_success_feedback_role_arn    = local.logs.application ? local.success_role_arn : null
  application_failure_feedback_role_arn    = local.logs.application ? local.failure_role_arn : null
  application_success_feedback_sample_rate = local.logs.application ? var.delivery_logging_sample_rate : null

  firehose_success_feedback_role_arn    = local.logs.firehose ? local.success_role_arn : null
  firehose_failure_feedback_role_arn    = local.logs.firehose ? local.failure_role_arn : null
  firehose_success_feedback_sample_rate = local.logs.firehose ? var.delivery_logging_sample_rate : null

  tags = local.common_tags

  # SNS starts assuming the logging role right away; let the role get its permissions first.
  depends_on = [aws_iam_role_policy.delivery_logging]
}

resource "aws_sns_topic_policy" "topic" {
  arn    = aws_sns_topic.topic.arn
  policy = local.topic_policy
}

# "Create and use new service roles": one role SNS assumes to write the topic's delivery
# status logs, for both successful and failed deliveries.
resource "aws_iam_role" "delivery_logging" {
  count = local.create_logging_role ? 1 : 0

  name        = "np-sns-logs-${var.service_id}"
  description = "Lets Amazon SNS write delivery status logs of ${var.topic_name} to CloudWatch Logs"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "sns.amazonaws.com" }
      Action    = "sts:AssumeRole"
      Condition = { StringEquals = { "aws:SourceAccount" = local.account_id } }
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy" "delivery_logging" {
  count = local.create_logging_role ? 1 : 0

  name = "cloudwatch-logs"
  role = aws_iam_role.delivery_logging[0].id

  # SNS logs to sns/<region>/<account>/<topic> and sns/<region>/<account>/<topic>/Failure.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:PutMetricFilter",
        "logs:PutRetentionPolicy",
      ]
      Resource = flatten([
        for group in ["sns/${var.region}/${local.account_id}/${var.topic_name}", "sns/${var.region}/${local.account_id}/${var.topic_name}/Failure"] : [
          "arn:${data.aws_partition.current.partition}:logs:${var.region}:${local.account_id}:log-group:${group}",
          "arn:${data.aws_partition.current.partition}:logs:${var.region}:${local.account_id}:log-group:${group}:*",
        ]
      ])
    }]
  })
}
