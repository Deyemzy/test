# Create the Lambda function
resource "aws_lambda_function" "backup_lambda" {
  function_name    = "backup_lambda_function"
  role             = aws_iam_role.backup_lambda_role.arn
  handler          = "backup_lambda_function.lambda_handler"
  runtime          = "python3.8"
  timeout          = 300
  memory_size      = 256
  filename         = "${path.module}/backup_lambda_function.py"
  source_code_hash = filebase64sha256("${path.module}/backup_lambda_function.py")
}

# Create the IAM role for the Lambda function
resource "aws_iam_role" "backup_lambda_role" {
  name = "backup_lambda_role"

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
resource "aws_iam_role_policy_attachment" "backup_lambda_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonESFullAccess"
  role       = aws_iam_role.backup_lambda_role.name
}
resource "aws_iam_role_policy_attachment" "backup_lambda_s3_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
  role       = aws_iam_role.backup_lambda_role.name
}

# Add the necessary Lambda environment variables
resource "aws_lambda_function_environment" "backup_lambda_environment" {
  function_name = aws_lambda_function.backup_lambda.function_name
  variables = {
    ES_HOST    = "https://vpc-common-services-dev-qn4cchq4sysegnr55kye4hgzga.us-west-2.es.amazonaws.com/"
    ES_REGION  = "us-west-2"
    BUCKET_NAME = var.bucket_name
  }
}

# Configure the event trigger for the Lambda function
resource "aws_cloudwatch_event_rule" "backup_lambda_trigger" {
  name        = "backup_lambda_trigger"
  description = "Event trigger for the backup Lambda function"
  schedule_expression = "cron(0 0 * * ? *)"  # Daily trigger at midnight
}

resource "aws_cloudwatch_event_target" "backup_lambda_target" {
  rule      = aws_cloudwatch_event_rule.backup_lambda_trigger.name
  arn       = aws_lambda_function.backup_lambda.arn
}
