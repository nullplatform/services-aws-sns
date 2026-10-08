#!/usr/bin/env bats

load helpers

setup() {
	setup_mocks
}

lib() {
	run bash -c "source '$SCRIPTS_DIR/sns_lib'; $*"
}

# Arguments of sns_delivery_policy for the console defaults, with overrides by position.
policy_args() {
	local args=(3 0 20 20 0 0 "" "text/plain; charset=UTF-8" linear false) i
	for i in "$@"; do args[${i%%=*}]="${i#*=}"; done
	printf "'%s' " "${args[@]}"
}

@test "checks whole numbers against their range and reads zero-padded ones as decimal" {
	lib "sns_whole_number 'maximum message size (KiB)' 256 1 1024"
	[ "$status" -eq 0 ]
	assert_equal "$output" "256"
	lib "sns_whole_number 'maximum message size (KiB)' 1025 1 1024"
	[ "$status" -ne 0 ]
	assert_contains "$output" "ERROR: maximum message size (KiB) must be between 1 and 1024, got 1025"
	lib "sns_whole_number 'wait' 08 0 20"
	assert_equal "$output" "8"
	for bad in "" "1.5" "-1" "1e3" "abc"; do
		lib "sns_whole_number 'retries' '$bad' 0 100"
		[ "$status" -ne 0 ]
		assert_contains "$output" "ERROR: retries must be a whole number, got '$bad'"
	done
}

@test "names a Standard topic np-<name> and a FIFO topic np-<name>.fifo" {
	lib "sns_topic_name standard orders"
	assert_equal "$output" "np-orders"
	lib "sns_topic_name fifo orders_v2-eu"
	assert_equal "$output" "np-orders_v2-eu.fifo"
}

@test "a 248-character name fits the 256-character limit on a FIFO topic and 249 does not" {
	name248=$(printf 'a%.0s' $(seq 1 248))
	lib "sns_topic_name fifo $name248"
	[ "$status" -eq 0 ]
	[ "${#output}" -eq 256 ]
	lib "sns_topic_name fifo ${name248}a"
	[ "$status" -ne 0 ]
	assert_contains "$output" "ERROR: name must be 1-248 characters"
}

@test "rejects names with spaces, dots or an empty name, and an unknown topic type" {
	for bad in "bad name" "has.dot" "" "ünï"; do
		lib "sns_topic_name standard '$bad'"
		[ "$status" -ne 0 ]
		assert_contains "$output" "ERROR: name must be 1-248 characters"
	done
	lib "sns_topic_name lifo orders"
	[ "$status" -ne 0 ]
	assert_contains "$output" "ERROR: topic_type must be standard or fifo, got 'lifo'"
}

@test "a display name is at most 100 characters" {
	lib "sns_require_display_name '$(printf 'a%.0s' $(seq 1 100))'"
	[ "$status" -eq 0 ]
	lib "sns_require_display_name '$(printf 'a%.0s' $(seq 1 101))'"
	[ "$status" -ne 0 ]
	assert_contains "$output" "ERROR: display_name must be at most 100 characters, got 101"
}

@test "accepts the default SNS key, alias names and key or alias ARNs, and rejects a bare key id" {
	for good in alias/aws/sns alias/team/topics \
		arn:aws:kms:us-east-1:688720756067:key/faccf791-ffcd-4193-8de3-503cd00c32d4 \
		arn:aws:kms:us-east-1:688720756067:alias/topics; do
		lib "sns_require_kms_key $good"
		[ "$status" -eq 0 ]
	done
	lib "sns_require_kms_key faccf791-ffcd-4193-8de3-503cd00c32d4"
	[ "$status" -ne 0 ]
	assert_contains "$output" "ERROR: kms_key_arn must be a KMS key ARN, an alias ARN or an alias name"
}

@test "validates IAM role ARNs" {
	lib "sns_require_role_arn 'IAM role for failed deliveries' arn:aws:iam::111122223333:role/service-role/SNSFailureFeedback"
	[ "$status" -eq 0 ]
	lib "sns_require_role_arn 'IAM role for failed deliveries' arn:aws:iam::111122223333:user/bob"
	[ "$status" -ne 0 ]
	assert_contains "$output" "ERROR: IAM role for failed deliveries must be an IAM role ARN"
}

@test "owner and everyone need no principals" {
	lib "sns_access_rule publishers owner '' '' 'owner everyone accounts'"
	assert_equal "$output" '{"mode":"owner","principals":[],"endpoints":[]}'
	lib "sns_access_rule publishers everyone 'leftover' '' 'owner everyone accounts'"
	assert_equal "$output" '{"mode":"everyone","principals":[],"endpoints":[]}'
}

@test "accounts are split on commas and new lines, trimmed and expanded to root ARNs" {
	lib "sns_access_rule publishers accounts \$' 111122223333 ,\n444455556666\n,arn:aws:iam::777788889999:role/worker,' '' 'owner everyone accounts'"
	[ "$status" -eq 0 ]
	assert_equal "$output" '{"mode":"accounts","principals":["arn:aws:iam::111122223333:root","arn:aws:iam::444455556666:root","arn:aws:iam::777788889999:role/worker"],"endpoints":[]}'
}

@test "accounts mode with an empty or invalid list is rejected" {
	lib "sns_access_rule subscribers accounts ' , ' '' 'owner everyone accounts endpoints'"
	[ "$status" -ne 0 ]
	assert_contains "$output" "ERROR: subscribers accounts needs at least one account ID or ARN"
	for bad in "12345" "*" "arn:aws:s3:::bucket"; do
		lib "sns_access_rule publishers accounts '$bad' '' 'owner everyone accounts'"
		[ "$status" -ne 0 ]
		assert_contains "$output" "ERROR: publishers accounts entry '$bad' is not a 12-digit account ID"
	done
}

@test "endpoints mode keeps wildcards and rejects an empty list or inner spaces" {
	lib "sns_access_rule subscribers endpoints '' ' *@example.com , https://hooks.example.com/* ' 'owner everyone accounts endpoints'"
	[ "$status" -eq 0 ]
	assert_equal "$output" '{"mode":"endpoints","principals":[],"endpoints":["*@example.com","https://hooks.example.com/*"]}'
	lib "sns_access_rule subscribers endpoints '' '' 'owner everyone accounts endpoints'"
	[ "$status" -ne 0 ]
	assert_contains "$output" "ERROR: subscribers endpoints needs at least one endpoint"
	lib "sns_access_rule subscribers endpoints '' 'a b' 'owner everyone accounts endpoints'"
	[ "$status" -ne 0 ]
	assert_contains "$output" "must not contain spaces"
}

@test "publishers cannot use the endpoints mode subscribers have" {
	lib "sns_access_rule publishers endpoints '' 'x' 'owner everyone accounts'"
	[ "$status" -ne 0 ]
	assert_contains "$output" "ERROR: publishers must be one of: owner everyone accounts; got 'endpoints'"
}

@test "an advanced policy must be a JSON object with a Statement, and is compacted" {
	lib "sns_require_policy_json '{ \"Version\": \"2012-10-17\", \"Statement\": [] }'"
	[ "$status" -eq 0 ]
	assert_equal "$output" '{"Version":"2012-10-17","Statement":[]}'
	lib "sns_require_policy_json '{\"Version\": \"2012-10-17\"'"
	[ "$status" -ne 0 ]
	assert_contains "$output" "ERROR: access_policy_json is not valid JSON"
	lib "sns_require_policy_json ''"
	[ "$status" -ne 0 ]
	lib "sns_require_policy_json '[1,2]'"
	[ "$status" -ne 0 ]
	assert_contains "$output" "ERROR: access_policy_json must be a JSON policy object with a Statement"
}

@test "the console defaults make the documented delivery policy" {
	lib "sns_delivery_policy $(policy_args)"
	[ "$status" -eq 0 ]
	assert_equal "$output" '{"http":{"defaultHealthyRetryPolicy":{"numRetries":3,"numNoDelayRetries":0,"minDelayTarget":20,"maxDelayTarget":20,"numMinDelayRetries":0,"numMaxDelayRetries":0,"backoffFunction":"linear"},"disableSubscriptionOverrides":false,"defaultRequestPolicy":{"headerContentType":"text/plain; charset=UTF-8"}}}'
}

@test "a maximum receive rate adds a throttle policy" {
	lib "sns_delivery_policy $(policy_args 6=5 9=true 8=exponential '7=application/json; charset=UTF-8')"
	[ "$status" -eq 0 ]
	assert_equal "$(echo "$output" | jq -c '.http.defaultThrottlePolicy')" '{"maxReceivesPerSecond":5}'
	assert_equal "$(echo "$output" | jq -r '.http.disableSubscriptionOverrides')" "true"
	assert_equal "$(echo "$output" | jq -r '.http.defaultHealthyRetryPolicy.backoffFunction')" "exponential"
	assert_equal "$(echo "$output" | jq -r '.http.defaultRequestPolicy.headerContentType')" "application/json; charset=UTF-8"
}

@test "the delivery policy enforces the console's limits" {
	lib "sns_delivery_policy $(policy_args 0=101)"
	assert_contains "$output" "ERROR: number of retries must be between 0 and 100, got 101"
	lib "sns_delivery_policy $(policy_args 2=30 3=20)"
	assert_contains "$output" "ERROR: minimum delay (30s) must not be higher than maximum delay (20s)"
	lib "sns_delivery_policy $(policy_args 3=3601)"
	assert_contains "$output" "ERROR: maximum delay (seconds) must be between 1 and 3600, got 3601"
	lib "sns_delivery_policy $(policy_args 1=2 4=1 5=1)"
	assert_contains "$output" "add up to 4, more than the 3 retries"
	lib "sns_delivery_policy $(policy_args 6=0)"
	assert_contains "$output" "ERROR: maximum receive rate (per second) must be between 1"
	lib "sns_delivery_policy $(policy_args '7=image/png')"
	assert_contains "$output" "ERROR: delivery policy Content-Type must be one of the offered values"
	lib "sns_delivery_policy $(policy_args 8=quadratic)"
	assert_contains "$output" "ERROR: retry-backoff function must be linear, arithmetic, geometric or exponential"
}

@test "turns tags into a map and rejects aws: keys" {
	lib "sns_user_tags_json '[{\"key\":\"team\",\"value\":\"payments\"},{\"key\":\" env \",\"value\":\" prod \"},{\"key\":\"\",\"value\":\"x\"}]'"
	assert_equal "$output" '{"team":"payments","env":"prod"}'
	lib "sns_user_tags_json '\"team=payments, expr=a=b\"'"
	assert_equal "$output" '{"team":"payments","expr":"a=b"}'
	lib "sns_user_tags_json 'null'"
	assert_equal "$output" "{}"
	lib "sns_user_tags_json '[{\"key\":\"aws:team\",\"value\":\"x\"}]'"
	[ "$status" -ne 0 ]
	assert_contains "$output" "ERROR: tag keys must not start with aws:"
}
