resource "aws_lambda_function" "check_acm_ssl" {
  function_name = var.lambda_function_name
  role          = aws_iam_role.lambda_role.arn
  handler       = "main.lambda_handler"
  runtime       = "python3.8"
  timeout       = 60

  environment {
    variables = {
      SLACK_WEBHOOK_URL = var.slack_webhook_url
      SLACK_CHANNEL     = var.slack_channel
      REGION            = var.region
    }
  }

  source_code_hash = filebase64sha256("lambda_function.zip")
  filename         = "lambda_function.zip"
}

resource "aws_lambda_permission" "allow_cloudwatch" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.check_acm_ssl.function_name
  principal     = "events.amazonaws.com"
}