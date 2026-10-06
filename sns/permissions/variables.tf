variable "link_id" {
  type        = string
  description = "Nullplatform link ID"
}

variable "region" {
  type        = string
  description = "AWS region"
}

variable "user_name" {
  type        = string
  description = "IAM user created for this link, derived from the link slug and ID by build_context"

  validation {
    condition     = can(regex("^np-[a-z0-9-]{1,56}-user$", var.user_name))
    error_message = "user_name must look like np-<slug>-<id>-user: lowercase letters, numbers and hyphens, at most 64 characters"
  }
}

variable "topic_arn" {
  type        = string
  description = "ARN of the topic the link grants access to"
}

variable "kms_key_id" {
  type        = string
  default     = ""
  description = "KMS key or alias of an encrypted topic (ARN or alias/<name>). Empty for unencrypted topics"
}
