resource "aws_opensearch_domain" "os" {
  provider       = aws.owner
  domain_name    = local.domain_name
  engine_version = "Elasticsearch_7.9"

  cluster_config {
    instance_type = var.instance_type
  }

  # Only applicable if the cluster is flagged as private
  dynamic "vpc_options" {
    for_each = var.public_facing == true ? [] : [1]
    content {
      subnet_ids         = data.aws_subnets.subnets.ids
      security_group_ids = [var.public_facing == false ? aws_security_group.es[0].id : ""]
    }
  }

  snapshot_options {
    automated_snapshot_start_hour = 23
  }

  ebs_options {
    ebs_enabled = true
    volume_size = var.storage_volume_size
    volume_type = "gp2"
  }

  encrypt_at_rest {
    enabled = true
  }

  domain_endpoint_options {
    enforce_https       = true
    tls_security_policy = "Policy-Min-TLS-1-2-2019-07"
  }

  advanced_security_options {
    enabled                        = true
    internal_user_database_enabled = true
    master_user_options {
      master_user_name     = var.name
      master_user_password = random_password.password.result
    }
  }

  node_to_node_encryption {
    enabled = true
  }

  dynamic "log_publishing_options" {
    for_each = toset(local.log_types)
    content {
      cloudwatch_log_group_arn = module.logging[log_publishing_options.key].log_group_arn
      log_type                 = log_publishing_options.key
    }
  }

  tags = {
    Name            = local.domain_name
    ServiceLinkRole = local.service_link_role
  }

}

resource "aws_opensearch_domain_policy" "main" {
  provider    = aws.owner
  domain_name = aws_opensearch_domain.os.domain_name

  access_policies = <<POLICIES
{
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
}
POLICIES
}
