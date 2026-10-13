# Evaluates the module against a mocked AWS provider: no credentials, nothing created.
mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = { account_id = "111122223333" }
  }
}

variables {
  link_id   = "link-1"
  region    = "us-west-2"
  user_name = "np-orders-api-7d9e2-user"
  topic_arn = "arn:aws:sns:us-west-2:111122223333:np-orders"
}

run "bounded_link_user" {
  assert {
    condition     = aws_iam_user.link.path == "/nullplatform/sns/"
    error_message = "the link user lives under the path the permissions role is scoped to"
  }
  assert {
    condition     = aws_iam_user.link.permissions_boundary == "arn:aws:iam::111122223333:policy/nullplatform/sns/np-sns-link-boundary"
    error_message = "the link user carries the boundary the permissions role requires"
  }
  assert {
    condition     = aws_iam_user.link.tags["link-id"] == "link-1"
    error_message = "the link user is tagged with the link"
  }
}

run "subscription_actions_on_the_topic" {
  assert {
    condition     = length(jsondecode(aws_iam_user_policy.link.policy).Statement) == 1
    error_message = "without a KMS key the link policy has a single statement"
  }
  assert {
    condition     = jsondecode(aws_iam_user_policy.link.policy).Statement[0].Resource == "arn:aws:sns:us-west-2:111122223333:np-orders"
    error_message = "SNS authorizes every topic and subscription action against the topic ARN"
  }
  assert {
    condition     = contains(jsondecode(aws_iam_user_policy.link.policy).Statement[0].Action, "sns:Unsubscribe")
    error_message = "the link can remove the subscriptions it creates"
  }
}
