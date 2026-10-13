variable "region" {
  description = "Region the IAM resources are created through. IAM is global; this only selects the API endpoint."
  type        = string
  default     = "us-east-1"
}

variable "agent_role_arn" {
  description = "ARN of the primary nullplatform agent IRSA role allowed to assume this permissions role via sts:AssumeRole, and always a trusted principal of the role's trust policy. Defaults (when empty) to the conventional agent role for the cluster: arn:aws:iam::<account>:role/nullplatform-<cluster_name>-agent-role."
  type        = string
  default     = ""

  validation {
    condition     = var.agent_role_arn == "" || can(regex("^arn:aws:iam::[0-9]{12}:role/.+", var.agent_role_arn))
    error_message = "agent_role_arn must be empty (to use the derived default) or match arn:aws:iam::<account-id>:role/<role-name>"
  }
}

variable "additional_agent_role_arns" {
  description = "Extra IAM role ARNs allowed to assume this permissions role, appended to agent_role_arn in the trust policy. Defaults to none."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for arn in var.additional_agent_role_arns : can(regex("^arn:aws:iam::[0-9]{12}:role/.+", arn))])
    error_message = "each additional_agent_role_arns entry must match arn:aws:iam::<account-id>:role/<role-name>"
  }
}

variable "cluster_name" {
  description = "Name of the cluster the nullplatform agent runs in. Used only to derive default names for the permissions role, the policy prefix and the agent role ARN."
  type        = string
}

variable "role_name" {
  description = "Override for the SNS permissions IAM role name. Defaults to nullplatform_{cluster_name}_sns_role."
  type        = string
  default     = ""
}

variable "policies_name_prefix" {
  description = "Override for the IAM policy name prefix. Defaults to nullplatform_{cluster_name}."
  type        = string
  default     = ""
}

variable "resource_name_prefix" {
  description = "Prefix of the topics, IAM users and delivery logging roles this service manages. The permissions are scoped to resources matching it, so the agent cannot reach topics, users or roles created outside nullplatform."
  type        = string
  default     = "np-"
}

variable "kms_key_arns" {
  description = "KMS keys the agent may use to create encrypted topics and resolve their keys for links (kms:DescribeKey, kms:GenerateDataKey, kms:Decrypt). Defaults to every key; restrict it to the keys your teams use."
  type        = list(string)
  default     = ["*"]
}

variable "iam_create_role" {
  description = "Whether to create the permissions role and its policies. When false, the module produces no resources."
  type        = bool
  default     = true
}

variable "iam_resource_tags_json" {
  description = "Tags to apply to IAM resources created by this module."
  type        = map(string)
  default     = {}
}

variable "state_bucket_name" {
  description = "Name of the existing S3 bucket holding the tofu state for every SNS service. The agent receives it as SNS_S3_STATE_BUCKET; this grants the permissions role access to the services/sns/ prefix of it."
  type        = string
}

variable "delivery_logging_role_arns" {
  description = "Existing IAM roles the agent may hand to SNS for delivery status logging (\"Use existing service roles\"), through iam:PassRole limited to sns.amazonaws.com. Defaults to every role; restrict it to the roles your teams use. Roles the service creates itself (np-sns-logs-*) are always allowed."
  type        = list(string)
  default     = ["*"]
}
