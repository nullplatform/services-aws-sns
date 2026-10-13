#!/usr/bin/env bats

load helpers

setup() {
	setup_mocks
	export CONTEXT
	CONTEXT=$(service_context '{}' "$(full_params)")
	rm -rf /tmp/np-service-0f3a6b1e-9c2d-4e8f-a1b2-c3d4e5f60718
}

with_params() {
	CONTEXT=$(echo "$CONTEXT" | jq "$1")
}

reset_params() {
	CONTEXT=$(service_context '{}' "$(full_params)")
}

@test "names a Standard topic np-<name> and exports it" {
	run_script build_context
	[ "$status" -eq 0 ]
	assert_equal "$(captured TOPIC_NAME)" "np-orders"
	assert_equal "$(tfvar topic_name)" "np-orders"
	assert_equal "$(tfvar fifo)" "false"
}

@test "names a FIFO topic np-<name>.fifo" {
	with_params '.parameters.topic_type = "fifo"'
	run_script build_context
	[ "$status" -eq 0 ]
	assert_equal "$(captured TOPIC_NAME)" "np-orders.fifo"
	assert_equal "$(tfvar fifo)" "true"
}

@test "keeps the topic name stored in the attributes when the parameters change" {
	CONTEXT=$(service_context '{"topic_name":"np-orders.fifo"}' '{"aws_region":"us-west-2","topic_type":"standard","name":"renamed"}')
	run_script build_context
	[ "$status" -eq 0 ]
	assert_equal "$(captured TOPIC_NAME)" "np-orders.fifo"
	assert_equal "$(tfvar fifo)" "true"
}

@test "rejects an invalid or missing name" {
	with_params '.parameters.name = "bad name!"'
	run_script build_context
	[ "$status" -ne 0 ]
	assert_contains "$captured_stderr" "ERROR: name must be 1-248 characters"

	with_params 'del(.parameters.name)'
	run_script build_context
	[ "$status" -ne 0 ]
	assert_contains "$captured_stderr" "ERROR: name must be 1-248 characters"
}

@test "applies the documented defaults: every optional section is off" {
	run_script build_context
	[ "$status" -eq 0 ]
	assert_equal "$(tfvar display_name)" ""
	assert_equal "$(tfvar max_message_size_bytes)" "262144"
	assert_equal "$(tfvar kms_key_id)" ""
	assert_equal "$(tfvar access_policy_method)" "basic"
	assert_equal "$(tfvar publishers)" "owner"
	assert_equal "$(tfvar subscribers)" "owner"
	assert_equal "$(tfvar publisher_principals)" "[]"
	assert_equal "$(tfvar access_policy_json)" ""
	assert_equal "$(tfvar delivery_policy_json)" ""
	assert_equal "$(tfvar delivery_logging_protocols)" "[]"
	assert_equal "$(tfvar archive_retention_days)" "0"
	assert_equal "$(tfvar active_tracing)" "false"
}

@test "a Standard topic ignores the FIFO-only settings a form could still carry" {
	with_params '.parameters += {fifo_throughput_scope: "topic", content_based_deduplication: true, archive_policy: "enabled", archive_retention_days: 10}'
	run_script build_context
	[ "$status" -eq 0 ]
	assert_equal "$(tfvar fifo_throughput_scope)" ""
	assert_equal "$(tfvar content_based_deduplication)" "false"
	assert_equal "$(tfvar archive_retention_days)" "0"
}

@test "a FIFO topic carries its throughput scope, deduplication and archive policy" {
	with_params '.parameters += {topic_type: "fifo"}'
	run_script build_context
	[ "$status" -eq 0 ]
	assert_equal "$(tfvar fifo_throughput_scope)" "MessageGroup"
	assert_equal "$(tfvar content_based_deduplication)" "false"
	assert_equal "$(tfvar archive_retention_days)" "0"

	with_params '.parameters += {fifo_throughput_scope: "topic", content_based_deduplication: true, archive_policy: "enabled"}'
	run_script build_context
	[ "$status" -eq 0 ]
	assert_equal "$(tfvar fifo_throughput_scope)" "Topic"
	assert_equal "$(tfvar content_based_deduplication)" "true"
	assert_equal "$(tfvar archive_retention_days)" "30"

	with_params '.parameters.archive_retention_days = 366'
	run_script build_context
	[ "$status" -ne 0 ]
	assert_contains "$captured_stderr" "ERROR: archive message retention period (days) must be between 1 and 365, got 366"
}

@test "rejects a broken switch value instead of reading it as disabled" {
	with_params '.parameters += {topic_type: "fifo", archive_policy: "maybe"}'
	run_script build_context
	[ "$status" -ne 0 ]
	assert_contains "$captured_stderr" "ERROR: archive_policy must be disabled or enabled, got 'maybe'"
}

@test "carries the display name and converts the message size to bytes" {
	with_params '.parameters += {display_name: "Orders", max_message_size_kib: 1024}'
	run_script build_context
	[ "$status" -eq 0 ]
	assert_equal "$(tfvar display_name)" "Orders"
	assert_equal "$(tfvar max_message_size_bytes)" "1048576"

	with_params '.parameters.max_message_size_kib = 0'
	run_script build_context
	[ "$status" -ne 0 ]
	assert_contains "$captured_stderr" "ERROR: maximum message size (KiB) must be between 1 and 1024, got 0"
}

@test "encryption uses alias/aws/sns unless another key is given, and ignores the key when off" {
	with_params '.parameters.encryption = "enabled"'
	run_script build_context
	[ "$status" -eq 0 ]
	assert_equal "$(tfvar kms_key_id)" "alias/aws/sns"

	with_params '.parameters.kms_key_arn = "arn:aws:kms:us-east-1:688720756067:key/faccf791-ffcd-4193-8de3-503cd00c32d4"'
	run_script build_context
	[ "$status" -eq 0 ]
	assert_equal "$(tfvar kms_key_id)" "arn:aws:kms:us-east-1:688720756067:key/faccf791-ffcd-4193-8de3-503cd00c32d4"

	with_params '.parameters += {encryption: "disabled", kms_key_arn: "garbage"}'
	run_script build_context
	[ "$status" -eq 0 ]
	assert_equal "$(tfvar kms_key_id)" ""

	with_params '.parameters.encryption = "enabled"'
	run_script build_context
	[ "$status" -ne 0 ]
	assert_contains "$captured_stderr" "ERROR: kms_key_arn must be a KMS key ARN"
}

@test "basic access policy: specified accounts publish, certain endpoints subscribe" {
	with_params '.parameters += {
		publishers: "accounts", publisher_accounts: "123456789123,123456789124",
		subscribers: "endpoints", subscriber_endpoints: "*@example.com"
	}'
	run_script build_context
	[ "$status" -eq 0 ]
	assert_equal "$(tfvar publishers)" "accounts"
	assert_equal "$(tfvar publisher_principals)" '["arn:aws:iam::123456789123:root","arn:aws:iam::123456789124:root"]'
	assert_equal "$(tfvar subscribers)" "endpoints"
	assert_equal "$(tfvar subscriber_endpoints)" '["*@example.com"]'
	assert_equal "$(tfvar subscriber_principals)" "[]"
}

@test "basic access policy: everyone, and accounts for subscribers" {
	with_params '.parameters += {publishers: "everyone", subscribers: "accounts", subscriber_accounts: "123456789123"}'
	run_script build_context
	[ "$status" -eq 0 ]
	assert_equal "$(tfvar publishers)" "everyone"
	assert_equal "$(tfvar subscriber_principals)" '["arn:aws:iam::123456789123:root"]'
}

@test "basic access policy rejects missing accounts" {
	with_params '.parameters += {publishers: "accounts"}'
	run_script build_context
	[ "$status" -ne 0 ]
	assert_contains "$captured_stderr" "ERROR: publishers accounts needs at least one account ID or ARN"
}

@test "advanced access policy passes the JSON through and skips the basic settings" {
	with_params '.parameters += {access_policy_method: "advanced", publishers: "accounts", access_policy_json: "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Principal\":\"*\",\"Action\":\"SNS:Publish\",\"Resource\":\"{{topic_arn}}\"}]}"}'
	run_script build_context
	[ "$status" -eq 0 ]
	assert_equal "$(tfvar access_policy_method)" "advanced"
	assert_equal "$(tfvar 'access_policy_json | fromjson | .Statement[0].Resource')" "{{topic_arn}}"
	assert_equal "$(tfvar ' | has("publishers")')" "false"

	with_params '.parameters.access_policy_json = "not json"'
	run_script build_context
	[ "$status" -ne 0 ]
	assert_contains "$captured_stderr" "ERROR: access_policy_json is not valid JSON"
}

@test "a custom delivery policy is built for a Standard topic" {
	with_params '.parameters += {delivery_policy: "custom", delivery_num_retries: 10, delivery_num_no_delay_retries: 2, delivery_min_delay_seconds: 5, delivery_max_delay_seconds: 60, delivery_max_receives_per_second: 3, delivery_backoff_function: "geometric", delivery_override_subscription_policy: true}'
	run_script build_context
	[ "$status" -eq 0 ]
	assert_equal "$(tfvar 'delivery_policy_json | fromjson | .http.defaultHealthyRetryPolicy | [.numRetries, .numNoDelayRetries, .minDelayTarget, .maxDelayTarget, .backoffFunction] | join(",")')" "10,2,5,60,geometric"
	assert_equal "$(tfvar 'delivery_policy_json | fromjson | .http.defaultThrottlePolicy.maxReceivesPerSecond')" "3"
	assert_equal "$(tfvar 'delivery_policy_json | fromjson | .http.disableSubscriptionOverrides')" "true"
}

@test "the default delivery policy and FIFO topics send none" {
	with_params '.parameters += {delivery_policy: "default", delivery_num_retries: 101}'
	run_script build_context
	[ "$status" -eq 0 ]
	assert_equal "$(tfvar delivery_policy_json)" ""

	with_params '.parameters += {topic_type: "fifo", delivery_policy: "custom"}'
	run_script build_context
	[ "$status" -eq 0 ]
	assert_equal "$(tfvar delivery_policy_json)" ""
}

@test "a custom delivery policy is validated" {
	with_params '.parameters += {delivery_policy: "custom", delivery_min_delay_seconds: 30, delivery_max_delay_seconds: 20}'
	run_script build_context
	[ "$status" -ne 0 ]
	assert_contains "$captured_stderr" "ERROR: minimum delay (30s) must not be higher than maximum delay (20s)"
}

@test "delivery status logging on a Standard topic takes every selected protocol and creates the role by default" {
	with_params '.parameters += {delivery_logging: "enabled", log_lambda: true, log_http: true, log_firehose: true, delivery_logging_sample_rate: 50}'
	run_script build_context
	[ "$status" -eq 0 ]
	assert_equal "$(tfvar delivery_logging_protocols)" '["lambda","http","firehose"]'
	assert_equal "$(tfvar delivery_logging_sample_rate)" "50"
	assert_equal "$(tfvar delivery_logging_roles)" "create"
	assert_equal "$(tfvar delivery_logging_success_role_arn)" ""
}

@test "delivery status logging on a FIFO topic only logs SQS" {
	with_params '.parameters += {topic_type: "fifo", delivery_logging: "enabled", log_lambda: true, log_sqs: true}'
	run_script build_context
	[ "$status" -eq 0 ]
	assert_equal "$(tfvar delivery_logging_protocols)" '["sqs"]'

	with_params '.parameters.log_sqs = false'
	run_script build_context
	[ "$status" -ne 0 ]
	assert_contains "$captured_stderr" "ERROR: delivery status logging is enabled but no protocol is selected"
}

@test "delivery status logging with existing roles needs both role ARNs" {
	with_params '.parameters += {delivery_logging: "enabled", log_sqs: true, delivery_logging_roles: "existing", delivery_logging_success_role_arn: "arn:aws:iam::111122223333:role/SNSSuccessFeedback", delivery_logging_failure_role_arn: "arn:aws:iam::111122223333:role/SNSFailureFeedback"}'
	run_script build_context
	[ "$status" -eq 0 ]
	assert_equal "$(tfvar delivery_logging_roles)" "existing"
	assert_equal "$(tfvar delivery_logging_failure_role_arn)" "arn:aws:iam::111122223333:role/SNSFailureFeedback"

	with_params 'del(.parameters.delivery_logging_failure_role_arn)'
	run_script build_context
	[ "$status" -ne 0 ]
	assert_contains "$captured_stderr" "ERROR: IAM role for failed deliveries must be an IAM role ARN"
}

@test "disabled delivery status logging ignores leftover protocols and roles" {
	with_params '.parameters += {delivery_logging: "disabled", log_sqs: true, delivery_logging_roles: "existing"}'
	run_script build_context
	[ "$status" -eq 0 ]
	assert_equal "$(tfvar delivery_logging_protocols)" "[]"
}

@test "active tracing turns on X-Ray" {
	with_params '.parameters.active_tracing = "enabled"'
	run_script build_context
	[ "$status" -eq 0 ]
	assert_equal "$(tfvar active_tracing)" "true"
}

@test "merges the developer's tags under the platform tags, which cannot be overridden" {
	with_params '.parameters.tags = [{"key":"team","value":"payments"},{"key":"account_id","value":"spoofed"}]'
	run_script build_context
	[ "$status" -eq 0 ]
	assert_equal "$(tfvar tags.team)" "payments"
	assert_equal "$(tfvar tags.account_id)" "2"
	assert_equal "$(tfvar 'tags | has("scope_id")')" "false"
}

@test "takes the region from the aws_region attribute without querying the account provider" {
	run_script build_context
	[ "$status" -eq 0 ]
	assert_equal "$(captured REGION)" "us-west-2"
	assert_not_contains "$(cat "$MOCK_LOG")" "np provider"
}

@test "resolves the region from the account provider when the attribute is absent" {
	with_params 'del(.parameters.aws_region)'
	export MOCK_NP_PROVIDERS='{"results":[{"id":"prov-1","data_source":{"stored_keys":["account.region"]}}]}'
	export MOCK_NP_PROVIDER='{"attributes":{"account":{"region":"eu-central-1"}}}'
	run_script build_context
	[ "$status" -eq 0 ]
	assert_equal "$(captured REGION)" "eu-central-1"
}

@test "keeps the service state under services/sns/<service id>/" {
	run_script build_context
	[ "$status" -eq 0 ]
	assert_equal "$(captured TFSTATE_BUCKET)" "np-sns-state"
	assert_equal "$(captured TFSTATE_KEY_PREFIX)" "services/sns/0f3a6b1e-9c2d-4e8f-a1b2-c3d4e5f60718/"
	assert_contains "$(captured TOFU_INIT_VARIABLES)" "-backend-config=key=services/sns/0f3a6b1e-9c2d-4e8f-a1b2-c3d4e5f60718/terraform.tfstate"
	assert_equal "$(captured TOFU_MODULE_DIR)" "$SERVICE_PATH/deployment"
}

@test "fails when the state bucket variable is missing or the bucket is unreachable" {
	export SNS_S3_STATE_BUCKET=""
	run_script build_context
	[ "$status" -ne 0 ]
	assert_contains "$captured_stderr" "ERROR: SNS_S3_STATE_BUCKET is not set."

	export SNS_S3_STATE_BUCKET="np-sns-state"
	export MOCK_BUCKET_EXISTS=1
	run_script build_context
	[ "$status" -ne 0 ]
	assert_contains "$captured_stderr" "ERROR: the state bucket np-sns-state does not exist or is not reachable from us-west-2."
}

@test "a link action derives the link user and skips the topic settings" {
	export ACTION_SOURCE=link
	CONTEXT=$(link_context '{"topic_name":"np-orders","aws_region":"us-west-2"}' '{}')
	run_script build_context
	[ "$status" -eq 0 ]
	assert_equal "$(captured LINK_USER_NAME)" "np-orders-api-7d9e2-user"
	assert_equal "$(captured TOPIC_NAME)" "np-orders"
	assert_equal "$(captured TOFU_VARIABLES)" ""
	[ ! -f "$(captured OUTPUT_DIR)/terraform.tfvars.json" ]
}

@test "a link action fails when the service has no topic yet" {
	export ACTION_SOURCE=link
	CONTEXT=$(link_context '{"aws_region":"us-west-2"}' '{}')
	run_script build_context
	[ "$status" -ne 0 ]
	assert_contains "$captured_stderr" "ERROR: the service has no topic_name attribute yet."
}

@test "deleting a service does not re-validate the form" {
	export SERVICE_ACTION_TYPE=delete
	CONTEXT=$(service_context '{"topic_name":"np-orders.fifo","publishers":"accounts","delivery_logging":"enabled"}' '{"aws_region":"us-west-2"}')
	run_script build_context
	[ "$status" -eq 0 ]
	assert_equal "$(tfvar topic_name)" "np-orders.fifo"
	assert_equal "$(tfvar fifo)" "true"
	assert_equal "$(tfvar ' | keys | join(",")')" "fifo,region,service_id,topic_name"
}

@test "creating or updating still validates the form" {
	export SERVICE_ACTION_TYPE=update
	with_params '.parameters += {publishers: "accounts", publisher_accounts: "nope"}'
	run_script build_context
	[ "$status" -ne 0 ]
	assert_contains "$captured_stderr" "ERROR: publishers accounts entry 'nope'"
}

@test "creating fails early when another topic already has the name, instead of taking it over" {
	export SERVICE_ACTION_TYPE=create
	export MOCK_EXISTING_TOPIC_TAGS='[{"Key":"service-id","Value":"another-service"}]'
	run_script build_context
	[ "$status" -ne 0 ]
	assert_contains "$captured_stderr" "ERROR: a topic named np-orders already exists in us-west-2 (it belongs to service another-service)."
	assert_contains "$(cat "$MOCK_LOG")" "sns get-topic-attributes --topic-arn arn:aws:sns:us-west-2:123456789012:np-orders"

	export MOCK_EXISTING_TOPIC_TAGS='[]'
	run_script build_context
	[ "$status" -ne 0 ]
	assert_contains "$captured_stderr" "ERROR: a topic named np-orders already exists in us-west-2."
}

@test "creating goes on when the name is free or the topic is this service's own from an earlier run" {
	export SERVICE_ACTION_TYPE=create
	run_script build_context
	[ "$status" -eq 0 ]
	assert_not_contains "$captured_stderr" "WARNING"

	export MOCK_EXISTING_TOPIC_TAGS='[{"Key":"service-id","Value":"0f3a6b1e-9c2d-4e8f-a1b2-c3d4e5f60718"}]'
	run_script build_context
	[ "$status" -eq 0 ]
}

@test "creating warns but goes on when the name cannot be checked, and updates never check it" {
	export SERVICE_ACTION_TYPE=create
	export MOCK_GET_TOPIC_ERROR="An error occurred (AuthorizationError) when calling the GetTopicAttributes operation"
	run_script build_context
	[ "$status" -eq 0 ]
	assert_contains "$captured_stderr" "WARNING: could not check whether np-orders already exists"

	export SERVICE_ACTION_TYPE=update
	export MOCK_EXISTING_TOPIC_TAGS='[{"Key":"service-id","Value":"another-service"}]'
	unset MOCK_GET_TOPIC_ERROR
	: > "$MOCK_LOG"
	run_script build_context
	[ "$status" -eq 0 ]
	assert_not_contains "$(cat "$MOCK_LOG")" "sns get-topic-attributes"
}
