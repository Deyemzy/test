# Define the backup Lambda function if backup is enabled
resource "aws_lambda_function" "backup_lambda" {
  function_name    = "opensearch_backup_lambda"
  role             = aws_iam_role.backup_lambda_role.arn
  handler          = "backup.lambda_handler"
  runtime          = "python3.9"
  timeout          = 30
  memory_size      = 256
  filename         = "${path.module}/backup.py"
  source_code_hash = filebase64sha256("${path.module}/backup.py")

  environment {
    variables = {
      DOMAIN_NAME          = var.domain_name
      BUCKET_NAME          = var.backup_bucket_name
      RETENTION_DAYS       = var.backup_retention_period
    }
  }

  # Conditionally enable this resource based on the backup variable
  count = var.backup ? 1 : 0
}

# IAM role for the Lambda function
resource "aws_iam_role" "backup_lambda_role" {
  name               = "backup_lambda_role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
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

# Attach the necessary policies to the IAM role
resource "aws_iam_role_policy_attachment" "backup_lambda_es_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonESFullAccess"
  role       = aws_iam_role.backup_lambda_role.name
}

resource "aws_iam_policy" "backup_lambda_s3_policy" {
  name        = "backup_lambda_s3_policy"
  description = "Allows backup Lambda function to access S3 for backups"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:GetObject",
        "s3:DeleteObject"
      ],
      "Resource": "arn:aws:s3:::${var.backup_bucket_name}/*"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "backup_lambda_s3_policy_attachment" {
  policy_arn = aws_iam_policy.backup_lambda_s3_policy.arn
  role       = aws_iam_role.backup_lambda_role.name
}

# Add the necessary Lambda environment variables
resource "aws_lambda_permission" "backup_lambda_permission" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.backup_lambda.arn
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.backup_lambda_trigger.arn
}

# Event trigger for the Lambda function
resource "aws_cloudwatch_event_rule" "backup_lambda_trigger" {
  name                = "backup_lambda_trigger"
  description         = "Event trigger for the backup Lambda function"
  schedule_expression = "cron(0 0 * * ? *)"
}

resource "aws_cloudwatch_event_target" "backup_lambda_target" {
  rule  = aws_cloudwatch_event_rule.backup_lambda_trigger.name
  arn   = aws_lambda_function.backup_lambda.arn
}



-----------------------------
output "backup_lambda_arn" {
  description = "The ARN of the backup Lambda function"
  value       = aws_lambda_function.backup_lambda.arn
}

output "backup_lambda_role_arn" {
  description = "The ARN of the IAM role attached to the backup Lambda function"
  value       = aws_iam_role.backup_lambda_role.arn
}

output "backup_lambda_execution_role_arn" {
  description = "The ARN of the execution role for the backup Lambda function"
  value       = aws_iam_role.backup_lambda_role.arn
}
