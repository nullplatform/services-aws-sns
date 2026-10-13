output "permissions_role_arn" {
  description = "ARN of the role the agent assumes to operate this service. Publish it to the nullplatform AWS IAM provider under selector \"sns\"."
  value       = local.iam_create ? aws_iam_role.nullplatform_sns[0].arn : ""
}

output "permissions_role_name" {
  description = "Name of the permissions role"
  value       = local.iam_create ? aws_iam_role.nullplatform_sns[0].name : ""
}

output "permissions_role_id" {
  description = "ID of the permissions role"
  value       = local.iam_create ? aws_iam_role.nullplatform_sns[0].id : ""
}

output "link_boundary_policy_arn" {
  description = "Permissions boundary every link IAM user must carry"
  value       = local.iam_create ? aws_iam_policy.link_boundary[0].arn : ""
}
