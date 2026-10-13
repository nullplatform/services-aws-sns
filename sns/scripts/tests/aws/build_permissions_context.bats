#!/usr/bin/env bats

load helpers

setup() {
	setup_mocks
	export LINK_ID="7d9e2f10-1234-4abc-9def-0123456789ab"
	export LINK_USER_NAME="np-orders-api-7d9e2-user"
	export REGION="us-west-2"
	export TFSTATE_BUCKET="np-sns-state"
	export TFSTATE_KEY_PREFIX="services/sns/0f3a6b1e-9c2d-4e8f-a1b2-c3d4e5f60718/"
	export CONTEXT
	CONTEXT=$(link_context '{"topic_arn":"arn:aws:sns:us-west-2:111122223333:np-orders","encryption":"disabled"}' '{}')
	rm -rf "/tmp/np-link-${LINK_ID}"
}

@test "points tofu at the permissions module and the link's own state file" {
	run_script build_permissions_context
	[ "$status" -eq 0 ]
	assert_equal "$(captured TOFU_MODULE_DIR)" "$SERVICE_PATH/permissions"
	assert_equal "$(captured OUTPUT_DIR)" "/tmp/np-link-7d9e2f10-1234-4abc-9def-0123456789ab"
	assert_contains "$(captured TOFU_INIT_VARIABLES)" "-backend-config=key=services/sns/0f3a6b1e-9c2d-4e8f-a1b2-c3d4e5f60718/links/7d9e2f10-1234-4abc-9def-0123456789ab.tfstate"
	assert_contains "$(captured TOFU_VARIABLES)" "-var-file=/tmp/np-link-7d9e2f10-1234-4abc-9def-0123456789ab/terraform.tfvars.json"
}

@test "passes the link, the user and the topic to the module" {
	run_script build_permissions_context
	[ "$status" -eq 0 ]
	assert_equal "$(tfvar link_id)" "7d9e2f10-1234-4abc-9def-0123456789ab"
	assert_equal "$(tfvar user_name)" "np-orders-api-7d9e2-user"
	assert_equal "$(tfvar region)" "us-west-2"
	assert_equal "$(tfvar topic_arn)" "arn:aws:sns:us-west-2:111122223333:np-orders"
	assert_equal "$(tfvar kms_key_id)" ""
}

@test "passes the KMS key only when the topic is encrypted, with alias/aws/sns as the default" {
	CONTEXT=$(link_context '{"topic_arn":"arn:aws:sns:us-west-2:111122223333:np-orders","encryption":"enabled","kms_key_arn":"arn:aws:kms:us-west-2:111122223333:alias/topics"}' '{}')
	run_script build_permissions_context
	[ "$status" -eq 0 ]
	assert_equal "$(tfvar kms_key_id)" "arn:aws:kms:us-west-2:111122223333:alias/topics"

	CONTEXT=$(link_context '{"topic_arn":"arn:aws:sns:us-west-2:111122223333:np-orders","encryption":"enabled"}' '{}')
	run_script build_permissions_context
	[ "$status" -eq 0 ]
	assert_equal "$(tfvar kms_key_id)" "alias/aws/sns"

	CONTEXT=$(link_context '{"topic_arn":"arn:aws:sns:us-west-2:111122223333:np-orders","encryption":"disabled","kms_key_arn":"alias/stale"}' '{}')
	run_script build_permissions_context
	[ "$status" -eq 0 ]
	assert_equal "$(tfvar kms_key_id)" ""
}

@test "fails when the service has no topic arn yet" {
	CONTEXT=$(link_context '{}' '{}')
	run_script build_permissions_context
	[ "$status" -ne 0 ]
	assert_contains "$captured_stderr" "ERROR: the service has no topic_arn attribute yet."
}

@test "fails when build_context did not run first" {
	unset LINK_ID
	run_script build_permissions_context
	[ "$status" -ne 0 ]
	assert_contains "$captured_stderr" "ERROR: LINK_ID is not set. build_context must run before this script."
}
