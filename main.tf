resource "aws_cloudwatch_event_rule" "eventbridge_rule" {
  count        = length(var.linked_account_ids)
  name         = "EventBridgeRule-${var.linked_account_ids[count.index]}"
  event_pattern = jsonencode({ "source": ["aws.config"], "detail-type": ["AWS API Call via CloudTrail"] })
  # ...
}
