resource "aws_lambda_function" "backup_lambda" {
  function_name    = "opensearch_backup"
  handler          = "backup_lambda_function.lambda_handler"
  runtime          = "python3.8"
  filename         = "${path.module}/backup_lambda_function.zip"
  source_code_hash = filebase64sha256("${path.module}/backup_lambda_function.zip")
  role             = aws_iam_role.backup_lambda_role.arn
}

resource "aws_iam_role" "backup_lambda_role" {
  name = "opensearch_backup_lambda_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "backup_lambda_policy_attachment" {
  role       = aws_iam_role.backup_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonESFullAccess"
}

resource "aws_lambda_permission" "backup_lambda_permission" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.backup_lambda.arn
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.backup_event_rule.arn
}

resource "aws_cloudwatch_event_rule" "backup_event_rule" {
  name        = "opensearch_backup_event_rule"
  description = "Schedule OpenSearch backup"
  schedule_expression = "rate(1 day)"
}

resource "aws_cloudwatch_event_target" "backup_event_target" {
  rule      = aws_cloudwatch_event_rule.backup_event_rule.name
  arn       = aws_lambda_function.backup_lambda.arn
  target_id = "opensearch_backup_target"
}
