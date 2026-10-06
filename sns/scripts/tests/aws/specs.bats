#!/usr/bin/env bats

load helpers

setup() {
	setup_mocks
	SPEC="$SERVICE_PATH/specs/service-spec.json.tpl"
	LINK="$SERVICE_PATH/specs/links/connect.json.tpl"
}

prop() {
	jq -r ".attributes.schema.properties.$1" "$SPEC"
}

# Every rule between the root of the form and a control, outermost first, as "field=value".
conditions() {
	jq -r --arg scope "#/properties/$1" '
		.attributes.schema.uiSchema as $ui
		| ([$ui | paths(type == "object" and .scope? == $scope)] | first) as $p
		| [range(0; ($p | length) + 1) as $i | $ui | getpath($p[0:$i]) | objects | .rule? // empty
			| "\(.condition.scope | sub("^#/properties/"; ""))=\(.condition.schema.const)"]
		| join(" ")' "$SPEC"
}

@test "both specs are valid JSON with the schema under attributes.schema" {
	jq -e '.attributes.schema.type == "object"' "$SPEC"
	jq -e '.attributes.schema.type == "object"' "$LINK"
}

@test "the service offers its link and the link slug matches" {
	assert_equal "$(jq -r .slug "$SPEC")" "aws-sns"
	assert_equal "$(jq -r '.available_links[0]' "$SPEC")" "create-aws-sns-link"
	assert_equal "$(jq -r .slug "$LINK")" "create-aws-sns-link"
}

@test "the topic type, name and FIFO throughput scope can only be set on create" {
	for p in topic_type name fifo_throughput_scope; do
		assert_equal "$(prop "$p.editableOn" | jq -c .)" '["create"]'
	done
	assert_equal "$(jq -c '.attributes.schema.required' "$SPEC")" '["topic_type","name"]'
}

@test "every other input can be changed after creation" {
	run jq -e '
		.attributes.schema.properties
		| to_entries
		| map(select(.key as $k | ["topic_type","name","fifo_throughput_scope","aws_region","topic_arn","topic_name"] | index($k) | not))
		| all(.value.editableOn == ["create","update"])' "$SPEC"
	[ "$status" -eq 0 ]
}

@test "the defaults match the ones build_context applies" {
	assert_equal "$(prop 'topic_type.default')" "standard"
	assert_equal "$(prop 'max_message_size_kib.default')" "256"
	assert_equal "$(prop 'fifo_throughput_scope.default')" "message_group"
	assert_equal "$(prop 'content_based_deduplication.default')" "false"
	assert_equal "$(prop 'encryption.default')" "disabled"
	assert_equal "$(prop 'kms_key_arn.default')" "alias/aws/sns"
	assert_equal "$(prop 'access_policy_method.default')" "basic"
	assert_equal "$(prop 'publishers.default')" "owner"
	assert_equal "$(prop 'subscribers.default')" "owner"
	assert_equal "$(prop 'archive_policy.default')" "disabled"
	assert_equal "$(prop 'archive_retention_days.default')" "30"
	assert_equal "$(prop 'delivery_policy.default')" "default"
	assert_equal "$(prop 'delivery_num_retries.default')" "3"
	assert_equal "$(prop 'delivery_num_no_delay_retries.default')" "0"
	assert_equal "$(prop 'delivery_min_delay_seconds.default')" "20"
	assert_equal "$(prop 'delivery_max_delay_seconds.default')" "20"
	assert_equal "$(prop 'delivery_num_min_delay_retries.default')" "0"
	assert_equal "$(prop 'delivery_num_max_delay_retries.default')" "0"
	assert_equal "$(prop 'delivery_max_receives_per_second.default')" "null"
	assert_equal "$(prop 'delivery_content_type.default')" "text/plain; charset=UTF-8"
	assert_equal "$(prop 'delivery_backoff_function.default')" "linear"
	assert_equal "$(prop 'delivery_override_subscription_policy.default')" "false"
	assert_equal "$(prop 'delivery_logging.default')" "disabled"
	assert_equal "$(prop 'delivery_logging_sample_rate.default')" "100"
	assert_equal "$(prop 'delivery_logging_roles.default')" "create"
	assert_equal "$(prop 'active_tracing.default')" "disabled"
	for p in log_lambda log_sqs log_http log_application log_firehose; do
		assert_equal "$(prop "$p.default")" "false"
	done
}

@test "the numeric limits match the AWS ranges build_context enforces" {
	range() { echo "$(prop "$1.minimum")-$(prop "$1.maximum")"; }
	assert_equal "$(range max_message_size_kib)" "1-1024"
	assert_equal "$(range archive_retention_days)" "1-365"
	assert_equal "$(range delivery_num_retries)" "0-100"
	assert_equal "$(range delivery_min_delay_seconds)" "1-3600"
	assert_equal "$(range delivery_max_delay_seconds)" "1-3600"
	assert_equal "$(range delivery_logging_sample_rate)" "0-100"
	assert_equal "$(prop 'delivery_max_receives_per_second.minimum')" "1"
	assert_equal "$(prop 'display_name.maxLength')" "100"
	assert_equal "$(prop 'name.pattern')" '^[A-Za-z0-9_-]{1,248}$'
}

@test "the enum values are the ones the scripts understand" {
	vals() { prop "$1.oneOf" | jq -c '[.[].const]'; }
	assert_equal "$(vals topic_type)" '["standard","fifo"]'
	assert_equal "$(vals fifo_throughput_scope)" '["message_group","topic"]'
	assert_equal "$(vals access_policy_method)" '["basic","advanced"]'
	assert_equal "$(vals publishers)" '["owner","everyone","accounts"]'
	assert_equal "$(vals subscribers)" '["owner","everyone","accounts","endpoints"]'
	assert_equal "$(vals delivery_policy)" '["default","custom"]'
	assert_equal "$(vals delivery_backoff_function)" '["linear","arithmetic","geometric","exponential"]'
	assert_equal "$(vals delivery_logging_roles)" '["create","existing"]'
	for p in encryption archive_policy delivery_logging active_tracing; do
		assert_equal "$(vals "$p")" '["disabled","enabled"]'
	done
}

@test "the Content-Type choices are exactly the ones sns_lib accepts" {
	source "$SCRIPTS_DIR/sns_lib"
	assert_equal "$(prop 'delivery_content_type.oneOf' | jq -c '[.[].const]')" "$(printf '%s\n' "${SNS_CONTENT_TYPES[@]}" | jq -R . | jq -sc .)"
}

@test "the service exports the topic arn and nothing secret" {
	assert_equal "$(prop 'topic_arn.export')" "true"
	assert_equal "$(prop 'topic_name.export')" "false"
	run jq -e '[.attributes.schema.properties[] | select(.export | type == "object")] | length == 0' "$SPEC"
	[ "$status" -eq 0 ]
}

@test "every control in the form points at a property and every input property has a control" {
	run jq -e '
		.attributes.schema as $s
		| [ $s.uiSchema | .. | objects | select(.type == "Control") | .scope | sub("^#/properties/"; "") ] as $controls
		| ($controls | all(. as $k | $s.properties | has($k)))
		  and (($s.properties | keys) - $controls - ["aws_region","topic_arn","topic_name"] == [])
		  and ($controls | length == (unique | length))' "$SPEC"
	[ "$status" -eq 0 ]
}

@test "FIFO-only settings appear only for FIFO topics" {
	assert_equal "$(conditions fifo_throughput_scope)" "topic_type=fifo"
	assert_equal "$(conditions content_based_deduplication)" "topic_type=fifo"
	assert_equal "$(conditions archive_policy)" "topic_type=fifo"
	assert_equal "$(conditions archive_retention_days)" "topic_type=fifo archive_policy=enabled"
}

@test "the HTTP/S delivery policy appears only for Standard topics, its fields only when customized" {
	assert_equal "$(conditions delivery_policy)" "topic_type=standard"
	for p in delivery_num_retries delivery_num_no_delay_retries delivery_min_delay_seconds delivery_max_delay_seconds \
		delivery_num_min_delay_retries delivery_num_max_delay_retries delivery_max_receives_per_second \
		delivery_content_type delivery_backoff_function delivery_override_subscription_policy; do
		assert_equal "$(conditions "$p")" "topic_type=standard delivery_policy=custom"
	done
}

@test "delivery status logging offers SQS to every topic and the other protocols to Standard topics" {
	assert_equal "$(conditions delivery_logging)" ""
	assert_equal "$(conditions log_sqs)" "delivery_logging=enabled"
	for p in log_lambda log_http log_application log_firehose; do
		assert_equal "$(conditions "$p")" "delivery_logging=enabled topic_type=standard"
	done
	assert_equal "$(conditions delivery_logging_sample_rate)" "delivery_logging=enabled"
	assert_equal "$(conditions delivery_logging_success_role_arn)" "delivery_logging=enabled delivery_logging_roles=existing"
	assert_equal "$(conditions delivery_logging_failure_role_arn)" "delivery_logging=enabled delivery_logging_roles=existing"
}

@test "the encryption key and the access policy details show only when they apply" {
	assert_equal "$(conditions kms_key_arn)" "encryption=enabled"
	assert_equal "$(conditions publishers)" "access_policy_method=basic"
	assert_equal "$(conditions publisher_accounts)" "access_policy_method=basic publishers=accounts"
	assert_equal "$(conditions subscriber_accounts)" "access_policy_method=basic subscribers=accounts"
	assert_equal "$(conditions subscriber_endpoints)" "access_policy_method=basic subscribers=endpoints"
	assert_equal "$(conditions access_policy_json)" "access_policy_method=advanced"
}

@test "settings shared by both types are always visible" {
	for p in topic_type name display_name max_message_size_kib encryption access_policy_method delivery_logging active_tracing tags; do
		assert_equal "$(conditions "$p")" ""
	done
	run jq -e '[.attributes.schema.uiSchema | .. | objects | select(has("rule")) | .rule.effect] | all(. == "SHOW")' "$SPEC"
	[ "$status" -eq 0 ]
}

@test "the hidden-when-off string fields accept an empty value" {
	for p in kms_key_arn delivery_logging_success_role_arn delivery_logging_failure_role_arn; do
		pattern=$(prop "$p.pattern")
		[[ "" =~ $pattern ]]
	done
}

@test "the link exports the credentials as secrets and the region as plain" {
	assert_equal "$(jq -r '.attributes.schema.properties.access_key_id.export' "$LINK")" "true"
	assert_equal "$(jq -c '.attributes.schema.properties.secret_access_key.export' "$LINK")" '{"type":"environment_variable","secret":true}'
	assert_equal "$(jq -r '.attributes.schema.properties.aws_region.export' "$LINK")" "true"
	assert_equal "$(jq -c '.attributes.schema.required' "$LINK")" '["access_key_id","secret_access_key"]'
}
