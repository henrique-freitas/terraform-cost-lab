output "task_role_arn" {
  value = aws_iam_role.task_definition_role.arn
}

output "task_role_name" {
  value = aws_iam_role.task_definition_role.name
}

output "task_definition_arn" {
  value = aws_ecs_task_definition.taskdef.arn
}

# output "private_load_balancer_dns" {
#   value = length(aws_lb.service_private_lb) > 0 ? aws_lb.service_private_lb[0].dns_name : null
# }

# output "secondary_private_load_balancer_dns" {
#   value = try(aws_lb.service_private_lb[1].dns_name, null)
# }

output "public_load_balancer_dns" {
  value = length(aws_lb.service_public_lb) > 0 ? aws_lb.service_public_lb[0].dns_name : null
}

output "secondary_public_load_balancer_dns" {
  value = try(aws_lb.service_public_lb[1].dns_name, null)
}

# output "private_load_balancer_arn_suffix" {
#   value = length(aws_lb.service_private_lb) > 0 ? aws_lb.service_private_lb[0].arn_suffix : null
# }

# output "private_load_balancer_name_pattern" {
#   value = "${var.service_name}-pr-${var.color}"
# }

# output "secondary_private_load_balancer_arn_suffix" {
#   value = try(aws_lb.service_private_lb[1].arn_suffix, null)
# }

output "public_load_balancer_arn_suffix" {
  value = length(aws_lb.service_public_lb) > 0 ? aws_lb.service_public_lb[0].arn_suffix : null
}

output "public_load_balancer_name_pattern" {
  value = "${var.service_name}-pu-${var.color}"
}

output "secondary_public_load_balancer_arn_suffix" {
  value = try(aws_lb.service_public_lb[1].arn_suffix, null)
}

output "private_target_group_names" {
  value = aws_lb_target_group.service_private_target_group.*.name
}

output "public_target_group_name" {
  value = aws_lb_target_group.service_public_target_group.*.name
}

output "private_target_group_arns" {
  value = aws_lb_target_group.service_private_target_group.*.arn
}

output "public_target_group_arns" {
  value = aws_lb_target_group.service_public_target_group.*.arn
}

output "private_target_group_arn_suffixes" {
  value = aws_lb_target_group.service_private_target_group.*.arn_suffix
}

output "public_target_group_arn_suffixes" {
  value = aws_lb_target_group.service_public_target_group.*.arn_suffix
}

output "docker_repository_url" {
  value = length(aws_ecr_repository.ecr) > 0 ? aws_ecr_repository.ecr[0].repository_url : null
}

output "name" {
  value = aws_ecs_service.service.name
}

# output "private_dns" {
#   value = length(aws_route53_record.private_lb) > 0 ? aws_route53_record.private_lb[0].fqdn : ""
# }

output "public_dns" {
  value = length(aws_route53_record.public_lb) > 0 ? aws_route53_record.public_lb[0].fqdn : ""
}

output "task_execution_role_arn" {
  value = try(aws_iam_role.task_execution_role[0].arn, "")
}

output "rendered_task_definition" {
  value = aws_ecs_task_definition.taskdef
}

output "scale_up_policy_arn" {
  value = concat(aws_appautoscaling_policy.ecs_policy_up.*.arn, [null])[0]
}

output "scale_down_policy_arn" {
  value = concat(aws_appautoscaling_policy.ecs_policy_down.*.arn, [null])[0]
}
