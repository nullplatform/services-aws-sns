#!/usr/bin/env bats

load helpers

setup() {
	setup_mocks
	LOCALS="$SERVICE_PATH/specs/requirements/aws/locals.tf"
}

@test "listing the state bucket is not restricted by prefix: HeadBucket and the S3 backend list without the service prefix" {
	run grep -n 's3:prefix' "$LOCALS"
	[ "$status" -ne 0 ]
	assert_contains "$(grep -A3 'ListStateBucket' "$LOCALS")" '"s3:ListBucket"'
}

@test "reading and writing state objects stays under services/sns/" {
	assert_contains "$(grep -A12 'ManageStateObjects' "$LOCALS")" 'services/sns/*'
}

@test "the agent can pass roles to SNS only, for delivery status logging" {
	block=$(grep -A6 'PassLoggingRolesToSns' "$LOCALS")
	assert_contains "$block" '"iam:PassRole"'
	assert_contains "$block" '"iam:PassedToService" = "sns.amazonaws.com"'
}

@test "the roles the service creates are scoped to the np-sns-logs- prefix the deployment module uses" {
	assert_contains "$(grep 'logging_roles_arn =' "$LOCALS")" 'role/${var.resource_name_prefix}sns-logs-*'
	assert_contains "$(grep 'name *= "np-sns-logs-' "$SERVICE_PATH/deployment/main.tf")" 'np-sns-logs-${var.service_id}'
}
