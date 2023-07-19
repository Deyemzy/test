resource "aws_opensearch_domain_policy" "main" {
  provider    = aws.owner
  domain_name = aws_opensearch_domain.os.domain_name

  access_policies = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": [
          "es:*",
          "logs:CreateLogStream"
        ],
        "Principal": "*",
        "Effect": "Allow",
        "Resource": "${aws_opensearch_domain.os.arn}/*",
        "Condition": {
          "StringLike": {
            "aws:ResourceTag/${aws_opensearch_domain.os.tags.Name}": "*"
          }
        }
      }
    ]
  })
}
