resource "aws_cloudwatch_event_rule" "every_day" {
  name                = "triggerEveryDay"
  schedule_expression = "rate(1 day)"
}

resource "aws_cloudwatch_event_target" "invoke_lambda" {
  rule      = aws_cloudwatch_event_rule.every_day.name
  target_id = "check_acm_ssl_expiration"
  arn       = aws_lambda_function.check_acm_ssl.arn
}