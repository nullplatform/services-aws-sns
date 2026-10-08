{
  "name": "AWS SNS",
  "slug": "aws-sns",
  "type": "dependency",
  "unique": false,
  "assignable_to": "any",
  "use_default_actions": true,
  "use_default_naming": false,
  "use_managed_actions": false,
  "available_links": [
    "create-aws-sns-link"
  ],
  "selectors": {
    "category": "Messaging",
    "imported": false,
    "provider": "AWS",
    "sub_category": "Pub/Sub"
  },
  "attributes": {
    "schema": {
      "type": "object",
      "$schema": "http://json-schema.org/draft-07/schema#",
      "additionalProperties": false,
      "required": ["topic_type", "name"],
      "uiSchema": {
        "type": "VerticalLayout",
        "elements": [
          { "type": "Control", "scope": "#/properties/topic_type", "options": { "format": "radio" } },
          { "type": "Control", "scope": "#/properties/name" },
          { "type": "Control", "scope": "#/properties/display_name" },
          { "type": "Control", "scope": "#/properties/max_message_size_kib" },
          {
            "type": "VerticalLayout",
            "rule": { "effect": "SHOW", "condition": { "scope": "#/properties/topic_type", "schema": { "const": "fifo" } } },
            "elements": [
              { "type": "Control", "scope": "#/properties/fifo_throughput_scope", "options": { "format": "radio" } },
              { "type": "Control", "scope": "#/properties/content_based_deduplication" }
            ]
          },
          {
            "type": "Categorization",
            "options": { "collapsable": { "label": "CONFIGURATION", "collapsed": false } },
            "elements": [
              {
                "type": "Category",
                "label": "Encryption",
                "elements": [
                  { "type": "Control", "scope": "#/properties/encryption", "options": { "format": "radio" } },
                  {
                    "type": "Control",
                    "scope": "#/properties/kms_key_arn",
                    "rule": { "effect": "SHOW", "condition": { "scope": "#/properties/encryption", "schema": { "const": "enabled" } } }
                  }
                ]
              },
              {
                "type": "Category",
                "label": "Access policy",
                "elements": [
                  { "type": "Control", "scope": "#/properties/access_policy_method", "options": { "format": "radio" } },
                  {
                    "type": "VerticalLayout",
                    "rule": { "effect": "SHOW", "condition": { "scope": "#/properties/access_policy_method", "schema": { "const": "basic" } } },
                    "elements": [
                      { "type": "Control", "scope": "#/properties/publishers", "options": { "format": "radio" } },
                      {
                        "type": "Control",
                        "scope": "#/properties/publisher_accounts",
                        "options": { "multi": true },
                        "rule": { "effect": "SHOW", "condition": { "scope": "#/properties/publishers", "schema": { "const": "accounts" } } }
                      },
                      { "type": "Control", "scope": "#/properties/subscribers", "options": { "format": "radio" } },
                      {
                        "type": "Control",
                        "scope": "#/properties/subscriber_accounts",
                        "options": { "multi": true },
                        "rule": { "effect": "SHOW", "condition": { "scope": "#/properties/subscribers", "schema": { "const": "accounts" } } }
                      },
                      {
                        "type": "Control",
                        "scope": "#/properties/subscriber_endpoints",
                        "options": { "multi": true },
                        "rule": { "effect": "SHOW", "condition": { "scope": "#/properties/subscribers", "schema": { "const": "endpoints" } } }
                      }
                    ]
                  },
                  {
                    "type": "Control",
                    "scope": "#/properties/access_policy_json",
                    "options": { "multi": true },
                    "rule": { "effect": "SHOW", "condition": { "scope": "#/properties/access_policy_method", "schema": { "const": "advanced" } } }
                  }
                ]
              },
              {
                "type": "Category",
                "label": "Archive policy",
                "rule": { "effect": "SHOW", "condition": { "scope": "#/properties/topic_type", "schema": { "const": "fifo" } } },
                "elements": [
                  { "type": "Control", "scope": "#/properties/archive_policy", "options": { "format": "radio" } },
                  {
                    "type": "Control",
                    "scope": "#/properties/archive_retention_days",
                    "rule": { "effect": "SHOW", "condition": { "scope": "#/properties/archive_policy", "schema": { "const": "enabled" } } }
                  }
                ]
              },
              {
                "type": "Category",
                "label": "Delivery policy (HTTP/S)",
                "rule": { "effect": "SHOW", "condition": { "scope": "#/properties/topic_type", "schema": { "const": "standard" } } },
                "elements": [
                  { "type": "Control", "scope": "#/properties/delivery_policy", "options": { "format": "radio" } },
                  {
                    "type": "VerticalLayout",
                    "rule": { "effect": "SHOW", "condition": { "scope": "#/properties/delivery_policy", "schema": { "const": "custom" } } },
                    "elements": [
                      { "type": "Control", "scope": "#/properties/delivery_num_retries" },
                      { "type": "Control", "scope": "#/properties/delivery_num_no_delay_retries" },
                      { "type": "Control", "scope": "#/properties/delivery_min_delay_seconds" },
                      { "type": "Control", "scope": "#/properties/delivery_max_delay_seconds" },
                      { "type": "Control", "scope": "#/properties/delivery_num_min_delay_retries" },
                      { "type": "Control", "scope": "#/properties/delivery_num_max_delay_retries" },
                      { "type": "Control", "scope": "#/properties/delivery_max_receives_per_second" },
                      { "type": "Control", "scope": "#/properties/delivery_content_type" },
                      { "type": "Control", "scope": "#/properties/delivery_backoff_function", "options": { "format": "radio" } },
                      { "type": "Control", "scope": "#/properties/delivery_override_subscription_policy" }
                    ]
                  }
                ]
              },
              {
                "type": "Category",
                "label": "Delivery status logging",
                "elements": [
                  { "type": "Control", "scope": "#/properties/delivery_logging", "options": { "format": "radio" } },
                  {
                    "type": "VerticalLayout",
                    "rule": { "effect": "SHOW", "condition": { "scope": "#/properties/delivery_logging", "schema": { "const": "enabled" } } },
                    "elements": [
                      {
                        "type": "Control",
                        "scope": "#/properties/log_lambda",
                        "rule": { "effect": "SHOW", "condition": { "scope": "#/properties/topic_type", "schema": { "const": "standard" } } }
                      },
                      { "type": "Control", "scope": "#/properties/log_sqs" },
                      {
                        "type": "Control",
                        "scope": "#/properties/log_http",
                        "rule": { "effect": "SHOW", "condition": { "scope": "#/properties/topic_type", "schema": { "const": "standard" } } }
                      },
                      {
                        "type": "Control",
                        "scope": "#/properties/log_application",
                        "rule": { "effect": "SHOW", "condition": { "scope": "#/properties/topic_type", "schema": { "const": "standard" } } }
                      },
                      {
                        "type": "Control",
                        "scope": "#/properties/log_firehose",
                        "rule": { "effect": "SHOW", "condition": { "scope": "#/properties/topic_type", "schema": { "const": "standard" } } }
                      },
                      { "type": "Control", "scope": "#/properties/delivery_logging_sample_rate" },
                      { "type": "Control", "scope": "#/properties/delivery_logging_roles", "options": { "format": "radio" } },
                      {
                        "type": "Control",
                        "scope": "#/properties/delivery_logging_success_role_arn",
                        "rule": { "effect": "SHOW", "condition": { "scope": "#/properties/delivery_logging_roles", "schema": { "const": "existing" } } }
                      },
                      {
                        "type": "Control",
                        "scope": "#/properties/delivery_logging_failure_role_arn",
                        "rule": { "effect": "SHOW", "condition": { "scope": "#/properties/delivery_logging_roles", "schema": { "const": "existing" } } }
                      }
                    ]
                  }
                ]
              },
              {
                "type": "Category",
                "label": "Active tracing",
                "elements": [
                  { "type": "Control", "scope": "#/properties/active_tracing", "options": { "format": "radio" } }
                ]
              }
            ]
          },
          { "type": "Control", "scope": "#/properties/tags" }
        ]
      },
      "properties": {
        "aws_region": {
          "type": "string",
          "title": "AWS Region",
          "config": "aws.region",
          "visibleOn": [],
          "editableOn": [],
          "description": "Region where the topic is created (taken from the account configuration)"
        },
        "topic_type": {
          "type": "string",
          "title": "Type",
          "default": "standard",
          "oneOf": [
            { "const": "standard", "title": "Standard: best-effort ordering, at-least-once delivery, highest throughput; SQS, Lambda, HTTP/S, SMS, email and mobile endpoints" },
            { "const": "fifo", "title": "FIFO (first-in, first-out): strictly-preserved ordering, exactly-once delivery; SQS subscriptions" }
          ],
          "description": "Cannot be changed after creation.",
          "editableOn": ["create"],
          "order": 1
        },
        "name": {
          "type": "string",
          "title": "Name",
          "pattern": "^[A-Za-z0-9_-]{1,248}$",
          "description": "Letters, numbers, hyphens and underscores, up to 248 characters. The topic is created in AWS as np-<name>, and a FIFO topic as np-<name>.fifo (you do not type the .fifo). Cannot be changed after creation.",
          "editableOn": ["create"],
          "order": 2
        },
        "display_name": {
          "type": "string",
          "title": "Display name - optional",
          "maxLength": 100,
          "description": "To use this topic with SMS subscriptions, enter a display name. Only the first 10 characters are displayed in an SMS message. Maximum 100 characters.",
          "editableOn": ["create", "update"],
          "order": 3
        },
        "max_message_size_kib": {
          "type": "integer",
          "title": "Maximum message size (KiB)",
          "default": 256,
          "minimum": 1,
          "maximum": 1024,
          "description": "The largest message size this topic accepts. Should be between 1 KiB and 1024 KiB.",
          "editableOn": ["create", "update"],
          "order": 4
        },
        "fifo_throughput_scope": {
          "type": "string",
          "title": "High throughput",
          "default": "message_group",
          "oneOf": [
            { "const": "message_group", "title": "Message group scope (recommended for highest throughput): maximum regional limits; message deduplication is only verified within a message group" },
            { "const": "topic", "title": "Topic scope: 3000 messages per second and 20 MB per second; message deduplication is verified on the entire FIFO topic" }
          ],
          "description": "FIFO only. Configure your FIFO topic for maximum throughput. Once set, this configuration cannot be modified.",
          "editableOn": ["create"],
          "order": 5
        },
        "content_based_deduplication": {
          "type": "boolean",
          "title": "Content-based message deduplication",
          "default": false,
          "description": "FIFO only. Enable default message deduplication based on message content. If unchecked, a deduplication ID must be provided for every publish request.",
          "editableOn": ["create", "update"],
          "order": 6
        },
        "encryption": {
          "type": "string",
          "title": "Encryption - optional",
          "default": "disabled",
          "oneOf": [
            { "const": "disabled", "title": "Disabled: in-transit encryption only (always on)" },
            { "const": "enabled", "title": "Enabled: server-side encryption adds at-rest encryption; SNS encrypts each message as soon as it is received and decrypts it right before delivery" }
          ],
          "editableOn": ["create", "update"],
          "order": 7
        },
        "kms_key_arn": {
          "type": "string",
          "title": "AWS KMS key",
          "default": "alias/aws/sns",
          "pattern": "^$|^alias/[A-Za-z0-9/_-]+$|^arn:aws[a-z-]*:kms:[a-z0-9-]+:[0-9]{12}:(key/[A-Za-z0-9-]+|alias/[A-Za-z0-9/_-]+)$",
          "description": "alias/aws/sns (the default key that protects SNS data when no other key is defined), or the ARN of a custom KMS key or alias, for example arn:aws:kms:us-east-1:123456789012:key/<id>. Applications linked to this topic are granted kms:GenerateDataKey and kms:Decrypt on it; a custom key's policy must allow them.",
          "editableOn": ["create", "update"],
          "order": 8
        },
        "access_policy_method": {
          "type": "string",
          "title": "Access policy - choose method",
          "default": "basic",
          "oneOf": [
            { "const": "basic", "title": "Basic: use simple criteria to define a basic access policy" },
            { "const": "advanced", "title": "Advanced: use a JSON object to define an advanced access policy" }
          ],
          "description": "Who can access your topic. By default, only the topic owner can publish or subscribe to the topic.",
          "editableOn": ["create", "update"],
          "order": 9
        },
        "publishers": {
          "type": "string",
          "title": "Publishers",
          "default": "owner",
          "oneOf": [
            { "const": "owner", "title": "Only the topic owner" },
            { "const": "everyone", "title": "Everyone: anybody can publish to the topic" },
            { "const": "accounts", "title": "Only the specified AWS accounts" }
          ],
          "description": "Specify who can publish messages to the topic.",
          "editableOn": ["create", "update"],
          "order": 10
        },
        "publisher_accounts": {
          "type": "string",
          "title": "Publisher AWS account IDs",
          "description": "AWS account IDs (or IAM user/role ARNs) separated by commas or new lines, for example 123456789123,123456789124",
          "editableOn": ["create", "update"],
          "order": 11
        },
        "subscribers": {
          "type": "string",
          "title": "Subscribers",
          "default": "owner",
          "oneOf": [
            { "const": "owner", "title": "Only the topic owner" },
            { "const": "everyone", "title": "Everyone: anybody can subscribe to the topic" },
            { "const": "accounts", "title": "Only the specified AWS accounts" },
            { "const": "endpoints", "title": "Only requesters with certain endpoints" }
          ],
          "description": "Specify who can subscribe to this topic.",
          "editableOn": ["create", "update"],
          "order": 12
        },
        "subscriber_accounts": {
          "type": "string",
          "title": "Subscriber AWS account IDs",
          "description": "AWS account IDs (or IAM user/role ARNs) separated by commas or new lines, for example 123456789123,123456789124",
          "editableOn": ["create", "update"],
          "order": 13
        },
        "subscriber_endpoints": {
          "type": "string",
          "title": "Subscriber endpoints",
          "description": "Only requesters whose endpoints match one of these values can subscribe, separated by commas or new lines. Wildcards are allowed, for example *@example.com, https://hooks.example.com/*, arn:aws:sqs:us-east-1:123456789012:*",
          "editableOn": ["create", "update"],
          "order": 14
        },
        "access_policy_json": {
          "type": "string",
          "title": "JSON access policy",
          "description": "The full topic policy, as in the SNS console's JSON editor. Leave Resource empty (or write {{topic_arn}}) where the topic ARN goes: the topic ARN is filled in when the policy is applied.",
          "editableOn": ["create", "update"],
          "order": 15
        },
        "archive_policy": {
          "type": "string",
          "title": "Archive policy - optional",
          "default": "disabled",
          "oneOf": [
            { "const": "disabled", "title": "Disabled: Amazon SNS does not retain your messages" },
            { "const": "enabled", "title": "Enabled: store messages so they can be resent to a subscription (additional pricing)" }
          ],
          "description": "FIFO only. Tells Amazon SNS how long to store your messages so that they can be resent to a subscription.",
          "editableOn": ["create", "update"],
          "order": 16
        },
        "archive_retention_days": {
          "type": "integer",
          "title": "Message retention period (days)",
          "default": 30,
          "minimum": 1,
          "maximum": 365,
          "description": "The number of days the archive of messages will be retained. 365 days maximum.",
          "editableOn": ["create", "update"],
          "order": 17
        },
        "delivery_policy": {
          "type": "string",
          "title": "Delivery policy (HTTP/S) - optional",
          "default": "default",
          "oneOf": [
            { "const": "default", "title": "Use the default delivery policy: 3 retries, 20 seconds delay, linear backoff, text/plain; charset=UTF-8" },
            { "const": "custom", "title": "Custom: configure how SNS retries failed deliveries to HTTP/S endpoints" }
          ],
          "description": "Standard only. Defines how Amazon SNS retries failed deliveries to HTTP/S endpoints.",
          "editableOn": ["create", "update"],
          "order": 18
        },
        "delivery_num_retries": {
          "type": "integer",
          "title": "Number of retries",
          "default": 3,
          "minimum": 0,
          "maximum": 100,
          "description": "Must be an integer from 0 to 100.",
          "editableOn": ["create", "update"],
          "order": 19
        },
        "delivery_num_no_delay_retries": {
          "type": "integer",
          "title": "Retries without delay",
          "default": 0,
          "minimum": 0,
          "maximum": 100,
          "description": "Must be lower than the total number of retries.",
          "editableOn": ["create", "update"],
          "order": 20
        },
        "delivery_min_delay_seconds": {
          "type": "integer",
          "title": "Minimum delay (seconds)",
          "default": 20,
          "minimum": 1,
          "maximum": 3600,
          "description": "Must be lower than maximum delay.",
          "editableOn": ["create", "update"],
          "order": 21
        },
        "delivery_max_delay_seconds": {
          "type": "integer",
          "title": "Maximum delay (seconds)",
          "default": 20,
          "minimum": 1,
          "maximum": 3600,
          "description": "Must be higher than minimum delay and lower than 3,600.",
          "editableOn": ["create", "update"],
          "order": 22
        },
        "delivery_num_min_delay_retries": {
          "type": "integer",
          "title": "Minimum delay retries",
          "default": 0,
          "minimum": 0,
          "maximum": 100,
          "description": "Must be lower than number of retries.",
          "editableOn": ["create", "update"],
          "order": 23
        },
        "delivery_num_max_delay_retries": {
          "type": "integer",
          "title": "Maximum delay retries",
          "default": 0,
          "minimum": 0,
          "maximum": 100,
          "description": "Must be lower than number of retries.",
          "editableOn": ["create", "update"],
          "order": 24
        },
        "delivery_max_receives_per_second": {
          "type": "integer",
          "title": "Maximum receive rate (per second)",
          "minimum": 1,
          "description": "Optional. Must be 1 or greater. Leave empty for no throttling.",
          "editableOn": ["create", "update"],
          "order": 25
        },
        "delivery_content_type": {
          "type": "string",
          "title": "Content-Type",
          "default": "text/plain; charset=UTF-8",
          "oneOf": [
            { "const": "text/plain; charset=UTF-8", "title": "text/plain; charset=UTF-8" },
            { "const": "application/json; charset=UTF-8", "title": "application/json; charset=UTF-8" },
            { "const": "application/xml; charset=UTF-8", "title": "application/xml; charset=UTF-8" },
            { "const": "text/html; charset=UTF-8", "title": "text/html; charset=UTF-8" },
            { "const": "text/xml; charset=UTF-8", "title": "text/xml; charset=UTF-8" }
          ],
          "editableOn": ["create", "update"],
          "order": 26
        },
        "delivery_backoff_function": {
          "type": "string",
          "title": "Retry-backoff function",
          "default": "linear",
          "oneOf": [
            { "const": "linear", "title": "Linear" },
            { "const": "arithmetic", "title": "Arithmetic" },
            { "const": "geometric", "title": "Geometric" },
            { "const": "exponential", "title": "Exponential" }
          ],
          "description": "The rate at which the delay increases from minimum to maximum.",
          "editableOn": ["create", "update"],
          "order": 27
        },
        "delivery_override_subscription_policy": {
          "type": "boolean",
          "title": "Override subscription policy",
          "default": false,
          "description": "Apply this policy to all subscriptions, even if they have their own policies.",
          "editableOn": ["create", "update"],
          "order": 28
        },
        "delivery_logging": {
          "type": "string",
          "title": "Message delivery status logging - optional",
          "default": "disabled",
          "oneOf": [
            { "const": "disabled", "title": "Disabled" },
            { "const": "enabled", "title": "Enabled: log the delivery status of messages to CloudWatch Logs" }
          ],
          "description": "These settings configure the logging of message delivery status to CloudWatch Logs.",
          "editableOn": ["create", "update"],
          "order": 29
        },
        "log_lambda": {
          "type": "boolean",
          "title": "AWS Lambda",
          "default": false,
          "editableOn": ["create", "update"],
          "order": 30
        },
        "log_sqs": {
          "type": "boolean",
          "title": "Amazon SQS",
          "default": false,
          "editableOn": ["create", "update"],
          "order": 31
        },
        "log_http": {
          "type": "boolean",
          "title": "HTTP/S",
          "default": false,
          "editableOn": ["create", "update"],
          "order": 32
        },
        "log_application": {
          "type": "boolean",
          "title": "Platform application endpoint",
          "default": false,
          "editableOn": ["create", "update"],
          "order": 33
        },
        "log_firehose": {
          "type": "boolean",
          "title": "Amazon Data Firehose",
          "default": false,
          "editableOn": ["create", "update"],
          "order": 34
        },
        "delivery_logging_sample_rate": {
          "type": "integer",
          "title": "Success sample rate (%)",
          "default": 100,
          "minimum": 0,
          "maximum": 100,
          "description": "The percentage of successful message deliveries to log.",
          "editableOn": ["create", "update"],
          "order": 35
        },
        "delivery_logging_roles": {
          "type": "string",
          "title": "IAM roles",
          "default": "create",
          "oneOf": [
            { "const": "create", "title": "Create and use new service roles: a role is created for the topic in IAM" },
            { "const": "existing", "title": "Use existing service roles: choose existing IAM roles" }
          ],
          "description": "Amazon SNS requires permission to write logs to CloudWatch Logs.",
          "editableOn": ["create", "update"],
          "order": 36
        },
        "delivery_logging_success_role_arn": {
          "type": "string",
          "title": "IAM role for successful deliveries",
          "pattern": "^$|^arn:aws[a-z-]*:iam::[0-9]{12}:role/[A-Za-z0-9+=,.@_/-]+$",
          "description": "ARN of a role that trusts sns.amazonaws.com and can write to CloudWatch Logs.",
          "editableOn": ["create", "update"],
          "order": 37
        },
        "delivery_logging_failure_role_arn": {
          "type": "string",
          "title": "IAM role for failed deliveries",
          "pattern": "^$|^arn:aws[a-z-]*:iam::[0-9]{12}:role/[A-Za-z0-9+=,.@_/-]+$",
          "description": "ARN of a role that trusts sns.amazonaws.com and can write to CloudWatch Logs.",
          "editableOn": ["create", "update"],
          "order": 38
        },
        "active_tracing": {
          "type": "string",
          "title": "Active tracing - optional",
          "default": "disabled",
          "oneOf": [
            { "const": "disabled", "title": "Don't use active tracing" },
            { "const": "enabled", "title": "Use active tracing: AWS X-Ray traces and service map in CloudWatch (additional costs apply)" }
          ],
          "description": "Use AWS X-Ray active tracing for this topic to view its traces and service map in Amazon CloudWatch.",
          "editableOn": ["create", "update"],
          "order": 39
        },
        "tags": {
          "type": "array",
          "title": "Tags - optional",
          "items": {
            "type": "object",
            "properties": {
              "key": { "type": "string", "title": "Key" },
              "value": { "type": "string", "title": "Value" }
            },
            "required": ["key"]
          },
          "description": "A tag is a metadata label that you can assign to the topic. Each tag consists of a key and an optional value.",
          "editableOn": ["create", "update"],
          "order": 40
        },
        "topic_arn": {
          "type": "string",
          "title": "Topic ARN",
          "export": true,
          "readOnly": true,
          "visibleOn": ["read"],
          "editableOn": [],
          "description": "ARN applications publish to and subscribe with (auto-populated after creation)",
          "order": 41
        },
        "topic_name": {
          "type": "string",
          "title": "Topic Name",
          "export": false,
          "readOnly": true,
          "visibleOn": [],
          "editableOn": [],
          "description": "Internal topic name, fixed after creation"
        }
      }
    },
    "values": {}
  }
}
