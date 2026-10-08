variable "service_id" {
  type        = string
  description = "Nullplatform service ID"
}

variable "region" {
  type        = string
  description = "AWS region"
}

variable "topic_name" {
  type        = string
  description = "Full AWS topic name (np-<name>, plus .fifo for FIFO). Derived once by build_context and frozen in the service attributes"

  validation {
    condition     = can(regex("^np-[A-Za-z0-9_-]{1,248}(\\.fifo)?$", var.topic_name))
    error_message = "topic_name must be np-<name> with a 1-248 character name of letters, numbers, hyphens and underscores, optionally ending in .fifo"
  }
}

variable "fifo" {
  type        = bool
  description = "Whether the topic is FIFO. Must agree with the .fifo suffix of topic_name"

  validation {
    condition     = var.fifo == endswith(var.topic_name, ".fifo")
    error_message = "fifo must be true exactly when topic_name ends in .fifo"
  }
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Extra tags applied to the topic"
}

variable "display_name" {
  type        = string
  default     = ""
  description = "Display name, used as the sender of SMS messages. Empty for none"

  validation {
    condition     = length(var.display_name) <= 100
    error_message = "display_name must be at most 100 characters"
  }
}

variable "max_message_size_bytes" {
  type    = number
  default = 262144

  validation {
    condition     = var.max_message_size_bytes >= 1024 && var.max_message_size_bytes <= 1048576
    error_message = "max_message_size_bytes must be between 1024 and 1048576"
  }
}

variable "fifo_throughput_scope" {
  type        = string
  default     = "MessageGroup"
  description = "FIFO only: MessageGroup (highest throughput, deduplication per message group) or Topic"

  validation {
    condition     = contains(["MessageGroup", "Topic", ""], var.fifo_throughput_scope)
    error_message = "fifo_throughput_scope must be MessageGroup or Topic"
  }
}

variable "content_based_deduplication" {
  type        = bool
  default     = false
  description = "FIFO only: deduplicate messages by a hash of their body"
}

variable "archive_retention_days" {
  type        = number
  default     = 0
  description = "FIFO only: days the archive policy keeps messages. 0 means no archive policy"

  validation {
    condition     = var.archive_retention_days >= 0 && var.archive_retention_days <= 365
    error_message = "archive_retention_days must be between 0 (no archive) and 365"
  }
}

variable "kms_key_id" {
  type        = string
  default     = ""
  description = "KMS key or alias (ARN or alias/<name>) for server-side encryption. Empty disables it"

  validation {
    condition     = var.kms_key_id == "" || can(regex("^(alias/[A-Za-z0-9/_-]+|arn:aws[a-z-]*:kms:[a-z0-9-]+:[0-9]{12}:(key/[A-Za-z0-9-]+|alias/[A-Za-z0-9/_-]+))$", var.kms_key_id))
    error_message = "kms_key_id must be a KMS key ARN, an alias ARN or an alias name"
  }
}

variable "access_policy_method" {
  type    = string
  default = "basic"

  validation {
    condition     = contains(["basic", "advanced"], var.access_policy_method)
    error_message = "access_policy_method must be basic or advanced"
  }
}

variable "publishers" {
  type        = string
  default     = "owner"
  description = "Basic policy: who can publish (owner, everyone or accounts)"

  validation {
    condition     = contains(["owner", "everyone", "accounts"], var.publishers)
    error_message = "publishers must be owner, everyone or accounts"
  }
}

variable "publisher_principals" {
  type        = list(string)
  default     = []
  description = "Basic policy: principals allowed to publish when publishers is accounts, as ARNs"

  validation {
    condition     = var.publishers != "accounts" || length(var.publisher_principals) > 0
    error_message = "publisher_principals must not be empty when publishers is accounts"
  }
}

variable "subscribers" {
  type        = string
  default     = "owner"
  description = "Basic policy: who can subscribe (owner, everyone, accounts or endpoints)"

  validation {
    condition     = contains(["owner", "everyone", "accounts", "endpoints"], var.subscribers)
    error_message = "subscribers must be owner, everyone, accounts or endpoints"
  }
}

variable "subscriber_principals" {
  type        = list(string)
  default     = []
  description = "Basic policy: principals allowed to subscribe when subscribers is accounts, as ARNs"

  validation {
    condition     = var.subscribers != "accounts" || length(var.subscriber_principals) > 0
    error_message = "subscriber_principals must not be empty when subscribers is accounts"
  }
}

variable "subscriber_endpoints" {
  type        = list(string)
  default     = []
  description = "Basic policy: endpoints (wildcards allowed) that may subscribe when subscribers is endpoints"

  validation {
    condition     = var.subscribers != "endpoints" || length(var.subscriber_endpoints) > 0
    error_message = "subscriber_endpoints must not be empty when subscribers is endpoints"
  }
}

variable "access_policy_json" {
  type        = string
  default     = ""
  description = "Advanced policy: the full JSON topic policy. {{topic_arn}} is replaced with the topic ARN"

  validation {
    condition     = var.access_policy_method != "advanced" || can(jsondecode(var.access_policy_json).Statement)
    error_message = "access_policy_json must be a JSON policy with a Statement when access_policy_method is advanced"
  }
}

variable "delivery_policy_json" {
  type        = string
  default     = ""
  description = "Standard only: HTTP/S delivery policy JSON. Empty keeps the SNS default"

  validation {
    condition     = var.delivery_policy_json == "" || can(jsondecode(var.delivery_policy_json).http)
    error_message = "delivery_policy_json must be a JSON delivery policy with an http section"
  }
}

variable "delivery_logging_protocols" {
  type        = list(string)
  default     = []
  description = "Protocols whose delivery status is logged to CloudWatch Logs. Empty disables logging"

  validation {
    condition     = alltrue([for p in var.delivery_logging_protocols : contains(["lambda", "sqs", "http", "application", "firehose"], p)])
    error_message = "delivery_logging_protocols entries must be lambda, sqs, http, application or firehose"
  }

  validation {
    condition     = !var.fifo || alltrue([for p in var.delivery_logging_protocols : p == "sqs"])
    error_message = "a FIFO topic can only log Amazon SQS deliveries"
  }
}

variable "delivery_logging_sample_rate" {
  type        = number
  default     = 100
  description = "Percentage of successful deliveries logged"

  validation {
    condition     = var.delivery_logging_sample_rate >= 0 && var.delivery_logging_sample_rate <= 100
    error_message = "delivery_logging_sample_rate must be between 0 and 100"
  }
}

variable "delivery_logging_roles" {
  type        = string
  default     = "create"
  description = "create: the module creates the role SNS logs with; existing: use the two role ARNs below"

  validation {
    condition     = contains(["create", "existing"], var.delivery_logging_roles)
    error_message = "delivery_logging_roles must be create or existing"
  }
}

variable "delivery_logging_success_role_arn" {
  type    = string
  default = ""

  validation {
    condition     = length(var.delivery_logging_protocols) == 0 || var.delivery_logging_roles != "existing" || can(regex("^arn:aws[a-z-]*:iam::[0-9]{12}:role/.+$", var.delivery_logging_success_role_arn))
    error_message = "delivery_logging_success_role_arn must be an IAM role ARN when delivery_logging_roles is existing"
  }
}

variable "delivery_logging_failure_role_arn" {
  type    = string
  default = ""

  validation {
    condition     = length(var.delivery_logging_protocols) == 0 || var.delivery_logging_roles != "existing" || can(regex("^arn:aws[a-z-]*:iam::[0-9]{12}:role/.+$", var.delivery_logging_failure_role_arn))
    error_message = "delivery_logging_failure_role_arn must be an IAM role ARN when delivery_logging_roles is existing"
  }
}

variable "active_tracing" {
  type        = bool
  default     = false
  description = "Send AWS X-Ray traces for this topic"
}
