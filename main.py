resource "aws_opensearch_domain_policy" "main" {
  provider    = aws.owner
  domain_name = aws_opensearch_domain.os.domain_name

  access_policies = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Action    = "es:*"
        Principal = "*"
        Effect    = "Allow"
        Resource  = "${aws_opensearch_domain.os.arn}/*"
      },
      {
        Action    = "logs:CreateLogStream"
        Effect    = "Allow"
        Principal = {
          Service = "es.amazonaws.com"
        }
        Resource  = "${module.logging["SEARCH_SLOW_LOGS"].log_group_arn}:*"
      },
      {
        Action    = "logs:PutLogEvents"
        Effect    = "Allow"
        Principal = {
          Service = "es.amazonaws.com"
        }
        Resource  = "${module.logging["SEARCH_SLOW_LOGS"].log_group_arn}:*"
      },
    ]
  })
}
