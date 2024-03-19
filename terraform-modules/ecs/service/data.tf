data "aws_iam_policy_document" "ecs-assume-role-policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "policies" {
  count = length(var.policies)
  dynamic "statement" {
    for_each = var.policies[count.index].permissions
    content {
      actions   = statement.value.actions
      resources = statement.value.resources
    }
  }
}

data "aws_vpc" "service_vpc" {
  id = var.vpc_id
}

data "aws_subnets" "default_private_subnet_ids" {
  count  = length(var.private_subnets) > 0 ? 0 : 1
 
  filter {
    name   = "tag:Name"
    values = ["DT Private 1b", "DT Private 1a"]
  }
}

data "aws_subnets" "default_public_subnet_ids" {
  count  = var.is_public && length(var.public_subnets) == 0 ? 1 : 0
  filter {
    name   = "tag:Name"
    values = ["DT Public 1a", "DT Public 1c"]
  }
}

data "aws_ecs_cluster" "ecs_cluster" {
  cluster_name = var.ecs_cluster
}

# data "aws_iam_policy_document" "task_execution_secret_policies" {
#   dynamic "statement" {
#     for_each = range(length(local.secret_secrets) > 0 ? 1 : 0)
#     content {
#       effect    = "Allow"
#       actions   = ["secretsmanager:GetSecretValue"]
#       resources = local.secret_secrets
#     }
#   }
#   dynamic "statement" {
#     for_each = range(length(local.secret_parameters) > 0 ? 1 : 0)
#     content {
#       effect    = "Allow"
#       actions   = ["ssm:GetParameter", "ssm:GetParameters"]
#       resources = local.secret_parameters
#     }
#   }
# }
