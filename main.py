# S3 bucket
resource "aws_s3_bucket" "backup_bucket" {
  bucket = var.backup_configuration.bucket_name
  tags = {
    Name        = var.backup_configuration.bucket_name
    Environment = var.environment_name
  }
}

# Lambda function if backup is enabled
resource "aws_lambda_function" "backup_lambda" {
  function_name    = "opensearch_backup_lambda"
  role             = aws_iam_role.backup_lambda_role.arn
  handler          = "backup.lambda_handler"
  runtime          = "python3.9"
  timeout          = 30
  memory_size      = 256
  filename         = "${path.module}/lambda/backup.py"
  source_code_hash = filebase64sha256("${path.module}/lambda/backup.py")

  environment {
    variables = {
      DOMAIN_NAME    = var.domain_name
      BUCKET_NAME    = var.backup_configuration.bucket_name
      RETENTION_DAYS = var.backup_configuration.retention_period
    }
  }

  count = var.backup_configuration.enabled ? 1 : 0
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
resource "aws_iam_role_policy_attachment" "backup_lambda_s3_policy_attachment" {
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
      "Resource": "arn:aws:s3:::${var.backup_configuration.bucket_name}/*"
    }
  ]
}
EOF
}

# Add the necessary Lambda environment variables
resource "aws_lambda_permission" "backup_lambda_permission" {
  count          = var.backup_configuration.enabled ? 1 : 0
  statement_id   = "AllowExecutionFromCloudWatch"
  action         = "lambda:InvokeFunction"
  function_name  = aws_lambda_function.backup_lambda[count.index].arn
  principal      = "events.amazonaws.com"
  source_arn     = aws_cloudwatch_event_rule.backup_lambda_trigger[count.index].arn
}

# Event trigger for the Lambda function
resource "aws_cloudwatch_event_rule" "backup_lambda_trigger" {
  count             = var.backup_configuration.enabled ? 1 : 0
  name              = "backup_lambda_trigger"
  description       = "Event trigger for the backup Lambda function"
  schedule_expression = "cron(0 0 * * ? *)"
}

resource "aws_cloudwatch_event_target" "backup_lambda_target" {
  count = var.backup_configuration.enabled ? 1 : 0
  rule  = aws_cloudwatch_event_rule.backup_lambda_trigger[count.index].name
  arn   = aws_lambda_function.backup_lambda[count.index].arn
}
