Sure, I understand. Here's how you can structure your Terraform code with modules placed in a "modules" directory inside the "src" directory:

First, create a directory structure like this:

```
auto_tagging_solution/
  |- main.tf
  |- variables.tf
  |- providers.tf
  |- src/
      |- modules/
           |- eventbridge/
           |    |- main.tf
           |    |- variables.tf
           |- sqs_queues/
           |    |- main.tf
           |    |- variables.tf
           |- lambda_functions/
                |- main.tf
                |- variables.tf
```

**auto_tagging_solution/main.tf:**

```hcl
variable "linked_account_ids" {
  type    = list(string)
  default = ["account_id_1", "account_id_2", "account_id_3"]  # Replace with actual account IDs
}

module "eventbridge" {
  source             = "./src/modules/eventbridge"
  linked_account_ids = var.linked_account_ids
}

module "sqs_queues" {
  source             = "./src/modules/sqs_queues"
  linked_account_ids = var.linked_account_ids
}

module "lambda_functions" {
  source             = "./src/modules/lambda_functions"
  linked_account_ids = var.linked_account_ids
}
```

**auto_tagging_solution/variables.tf:**

```hcl
variable "linked_account_ids" {
  type    = list(string)
  default = []
}
```

**auto_tagging_solution/providers.tf:**

```hcl
provider "aws" {
  region = "us-east-1"  # Replace with your desired region
}
```

Now, place the module files in the respective directories:

**auto_tagging_solution/src/modules/eventbridge/main.tf:**

```hcl
variable "linked_account_ids" {}

resource "aws_cloudwatch_event_rule" "eventbridge_rule" {
  count = length(var.linked_account_ids)
  name  = "EventBridgeRule-${var.linked_account_ids[count.index]}"
  # ...
}

output "eventbridge_rule_names" {
  value = aws_cloudwatch_event_rule.eventbridge_rule[*].name
}
```

**auto_tagging_solution/src/modules/sqs_queues/main.tf:**

```hcl
variable "linked_account_ids" {}

resource "aws_sqs_queue" "resource_discovery_queue" {
  count = length(var.linked_account_ids)
  # ...
}

resource "aws_sqs_queue" "tag_validation_queue" {
  count = length(var.linked_account_ids)
  # ...
}

resource "aws_sqs_queue" "tag_resources_queue" {
  count = length(var.linked_account_ids)
  # ...
}

output "sqs_queue_names" {
  value = [
    aws_sqs_queue.resource_discovery_queue[*].name,
    aws_sqs_queue.tag_validation_queue[*].name,
    aws_sqs_queue.tag_resources_queue[*].name,
  ]
}
```

**auto_tagging_solution/src/modules/lambda_functions/main.tf:**

```hcl
variable "linked_account_ids" {}

resource "aws_lambda_function" "resource_discovery_lambda" {
  count         = length(var.linked_account_ids)
  # ...
}

resource "aws_lambda_function" "tag_validation_lambda" {
  count         = length(var.linked_account_ids)
  # ...
}

resource "aws_lambda_function" "tag_resources_lambda" {
  count         = length(var.linked_account_ids)
  # ...
}

# IAM Role for Lambda Functions
resource "aws_iam_role" "lambda_role" {
  name = "lambda-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

output "lambda_function_names" {
  value = [
    aws_lambda_function.resource_discovery_lambda[*].function_name,
    aws_lambda_function.tag_validation_lambda[*].function_name,
    aws_lambda_function.tag_resources_lambda[*].function_name,
  ]
}
```

With this structure, the modules are located inside the "src/modules" directory, and the main configuration in the "auto_tagging_solution" directory references these modules. This approach helps keep your code organized and modular.

Please replace placeholders with actual configurations, paths, and other details as needed.
