output "topic_arn" {
  value       = aws_sns_topic.topic.arn
  description = "ARN applications publish to and subscribe with"
}

output "topic_name" {
  value       = aws_sns_topic.topic.name
  description = "Topic name, persisted in the service attributes so later actions reuse it"
}
