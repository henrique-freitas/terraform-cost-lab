locals {
  protocol_to_load_balancer = {
    TCP   = "network"
    UDP   = "network"
    HTTP  = "application"
    HTTPS = "application"
  }
  scheduling_strategy   = var.scheduling_strategy == null ? "REPLICA" : var.scheduling_strategy
  lb_listener_ports     = length(var.load_balancer_custom_ports) > 0 ? var.load_balancer_custom_ports.*.port : var.exposed_ports.*.port
  lb_listener_protocols = length(var.load_balancer_custom_ports) > 0 ? var.load_balancer_custom_ports.*.protocol : var.exposed_ports.*.protocol
  contains_443          = contains(local.lb_listener_ports, 443)
  redirect_80_443       = !var.disable_load_balancer && local.contains_443 ? upper(local.lb_listener_protocols[index(local.lb_listener_ports, 443)]) == "HTTPS" ? 1 : 0 : 0
  allow_scale           = var.min_tasks > 0 && var.max_tasks > 0 && var.min_tasks < var.max_tasks && !var.disable_scaling && upper(local.scheduling_strategy) != "DAEMON"
  scaling_configuration = local.allow_scale ? var.scaling_custom_configuration != null ? var.scaling_custom_configuration : var.default_scaling_configuration : null
  scale_up_alarms = local.scaling_configuration != null ? [
    for s in local.scaling_configuration["thresholds"] : {
      metric_name = s["metric"]
      periods     = s["periods"]
      period      = s["period"]
      threshold   = s["out_target"]
    } if s["out_target"] != null
  ] : []
  scale_down_alarms = local.scaling_configuration != null ? [
    for s in local.scaling_configuration["thresholds"] : {
      metric_name = s["metric"]
      periods     = s["periods"]
      period      = s["period"]
      threshold   = s["in_target"]
    } if s["in_target"] != null
  ] : []

  max_tasks       = var.max_tasks == 0 && var.service_desired_count > 0 ? var.service_desired_count : var.max_tasks
  public_subnets  = length(var.public_subnets) == 0 && var.is_public ? data.aws_subnets.default_public_subnet_ids[0].ids : var.public_subnets
  private_subnets = length(var.private_subnets) == 0 ? data.aws_subnets.default_private_subnet_ids[0].ids : var.private_subnets

  lb_types = distinct(sort([for l in local.lb_listener_protocols : local.protocol_to_load_balancer[upper(l)]]))
  lb_type_to_lb = {
    application = 0
    network     = tonumber(length(local.lb_types) - 1)
  }

  # parsed_container_definitions = jsondecode(var.container_definitions)
  # secret_parameters = compact([
  #   for s in flatten(local.parsed_container_definitions[*].secrets[*].valueFrom) :
  #   replace(s, "/^[^:]*:[^:]*:([^:]*):.*$/", "$1") == "ssm" ? s : ""
  # ])
  # secret_secrets = compact([
  #   for s in flatten(local.parsed_container_definitions[*].secrets[*].valueFrom) :
  #   replace(s, "/^[^:]*:[^:]*:([^:]*):.*$/", "$1") == "secretsmanager" ? s : ""
  # ])
  # has_secrets = length(concat(local.secret_parameters, local.secret_secrets)) > 0
}

resource "aws_iam_role" "task_execution_role" {
  count              = var.create_secrets_role ? 1 : 0
  name               = !var.task_execution_role_random_name ? "${var.service_name}-task-execution-role" : null
  assume_role_policy = data.aws_iam_policy_document.ecs-assume-role-policy.json
}

# resource "aws_iam_role_policy" "task_execution_secret_policy" {
#   count  = var.create_secrets_role ? 1 : 0
#   policy = data.aws_iam_policy_document.task_execution_secret_policies.json
#   role   = aws_iam_role.task_execution_role[0].id
# }

resource "aws_iam_role_policy_attachment" "ecs_base_execution_role_attachment" {
  count      = var.create_secrets_role ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
  role       = aws_iam_role.task_execution_role[0].id
}

resource "aws_ecs_service" "service" {
  name                = "${var.service_name}-${var.color}"
  cluster             = data.aws_ecs_cluster.ecs_cluster.arn
  task_definition     = aws_ecs_task_definition.taskdef.arn
  desired_count       = var.service_desired_count
  scheduling_strategy = var.scheduling_strategy

  dynamic "ordered_placement_strategy" {
    for_each = var.ordered_placement_strategies
    content {
      type  = ordered_placement_strategy.value.type
      field = ordered_placement_strategy.value.field
    }
  }
  dynamic "load_balancer" {
    for_each = var.target_group_arns
    content {
      target_group_arn = load_balancer.value
      container_name   = var.service_name
      container_port   = var.exposed_ports[load_balancer.key].port
    }
  }

  # dynamic "load_balancer" {
  #   for_each = !var.disable_load_balancer ? var.exposed_ports : []
  #   content {
  #     target_group_arn = aws_lb_target_group.service_private_target_group[load_balancer.key].arn
  #     container_name   = var.service_name
  #     container_port   = load_balancer.value.port
  #   }
  # }

  dynamic "load_balancer" {
    for_each = !var.disable_load_balancer && var.is_public ? var.exposed_ports : []
    content {
      target_group_arn = aws_lb_target_group.service_public_target_group[load_balancer.key].arn
      container_name   = var.service_name
      container_port   = load_balancer.value.port
    }
  }

  dynamic "placement_constraints" {
    for_each = var.service_placement_constraints
    content {
      type       = placement_constraints.value.type
      expression = placement_constraints.value.expression
    }
  }

  dynamic "capacity_provider_strategy" {
    for_each = var.capacity_provider_strategies
    content {
      capacity_provider = capacity_provider_strategy.value.capacity_provider
      weight            = capacity_provider_strategy.value.weight
      base              = capacity_provider_strategy.value.base
    }
  }
  lifecycle {
    ignore_changes = [desired_count, task_definition]
  }

  # depends_on = [
  #   aws_lb.service_private_lb,
  #   aws_lb.service_public_lb,
  #   aws_lb_target_group.service_private_target_group,
  #   aws_lb_target_group.service_public_target_group
  # ]
  # tags = local.tags
}

resource "aws_appautoscaling_target" "ecs_target" {
  count              = local.allow_scale ? 1 : 0
  max_capacity       = local.max_tasks
  min_capacity       = var.min_tasks
  resource_id        = "service/${var.ecs_cluster}/${aws_ecs_service.service.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "ecs_policy_up" {
  count              = local.allow_scale ? 1 : 0
  name               = "${var.service_name}-scale-up"
  resource_id        = aws_appautoscaling_target.ecs_target[0].resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target[0].service_namespace

  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = local.scaling_configuration.out_cooldown
    metric_aggregation_type = "Average"

    step_adjustment {
      metric_interval_lower_bound = 0
      scaling_adjustment          = 1
    }
  }
}

resource "aws_appautoscaling_policy" "ecs_policy_down" {
  count              = local.allow_scale ? 1 : 0
  name               = "${var.service_name}-scale-down"
  resource_id        = aws_appautoscaling_target.ecs_target[0].resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target[0].service_namespace

  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = local.scaling_configuration.in_cooldown
    metric_aggregation_type = "Average"

    step_adjustment {
      metric_interval_upper_bound = 0
      scaling_adjustment          = -1
    }
  }
}

resource "aws_cloudwatch_metric_alarm" "ecs_scale_up_alarm" {
  count               = local.allow_scale ? length(local.scale_up_alarms) : 0
  alarm_name          = "${aws_ecs_service.service.name}_${local.scaling_configuration.thresholds[count.index].metric}_up"
  metric_name         = local.scale_up_alarms[count.index]["metric_name"]
  statistic           = "Average"
  namespace           = "AWS/ECS"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = local.scale_up_alarms[count.index]["periods"]
  period              = local.scale_up_alarms[count.index]["period"]
  threshold           = local.scale_up_alarms[count.index]["threshold"]
  dimensions = {
    ClusterName = var.ecs_cluster
    ServiceName = aws_ecs_service.service.name
  }
  alarm_actions = [aws_appautoscaling_policy.ecs_policy_up[0].arn]
}

resource "aws_cloudwatch_metric_alarm" "ecs_scale_down_alarm" {
  count               = local.allow_scale ? length(local.scale_down_alarms) : 0
  alarm_name          = "${aws_ecs_service.service.name}_${local.scaling_configuration.thresholds[count.index].metric}_down"
  metric_name         = local.scale_down_alarms[count.index]["metric_name"]
  statistic           = "Average"
  namespace           = "AWS/ECS"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = local.scale_down_alarms[count.index]["periods"]
  period              = local.scale_down_alarms[count.index]["period"]
  threshold           = local.scale_down_alarms[count.index]["threshold"]
  dimensions = {
    ClusterName = var.ecs_cluster
    ServiceName = aws_ecs_service.service.name
  }
  alarm_actions = [aws_appautoscaling_policy.ecs_policy_down[0].arn]
}

resource "aws_lb_target_group" "service_private_target_group" {
  count                = !var.disable_load_balancer ? length(var.exposed_ports) : 0
  name                 = "${var.service_name}-pr-${var.color}-${var.exposed_ports[count.index].port}"
  protocol             = var.exposed_ports[count.index].protocol
  vpc_id               = data.aws_vpc.service_vpc.id
  port                 = var.exposed_ports[count.index].port
  tags                 = local.tags
  deregistration_delay = var.target_group_deregistration_delay

  dynamic "health_check" {
    for_each = var.exposed_ports[count.index].protocol != "UDP" && var.exposed_ports[count.index] != null ? [1] : []
    content {
      enabled             = true
      protocol            = upper(var.exposed_ports[count.index].health_check.protocol)
      port                = "traffic-port"
      interval            = var.exposed_ports[count.index].health_check.interval
      path                = var.exposed_ports[count.index].health_check.path
      timeout             = var.exposed_ports[count.index].health_check.timeout
      healthy_threshold   = var.exposed_ports[count.index].health_check.healthy_threshold
      unhealthy_threshold = var.exposed_ports[count.index].health_check.unhealthy_threshold
      matcher             = var.exposed_ports[count.index].health_check.matcher
    }
  }

  load_balancing_algorithm_type = var.load_balancing_algorithm_type

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb_target_group" "service_public_target_group" {
  count                = var.is_public && !var.disable_load_balancer ? length(var.exposed_ports) : 0
  name                = "${var.service_name}-pu-${var.color}-${var.exposed_ports[count.index].port}"
  protocol             = var.exposed_ports[count.index].protocol
  vpc_id               = data.aws_vpc.service_vpc.id
  port                 = var.exposed_ports[count.index].port
  tags                 = local.tags
  deregistration_delay = var.target_group_deregistration_delay

  dynamic "health_check" {
    for_each = var.exposed_ports[count.index].protocol != "UDP" && var.exposed_ports[count.index] != null ? [1] : []
    content {
      enabled             = var.exposed_ports[count.index].health_check != null
      protocol            = upper(var.exposed_ports[count.index].health_check.protocol)
      port                = "traffic-port"
      interval            = var.exposed_ports[count.index].health_check.interval
      path                = var.exposed_ports[count.index].health_check.path
      timeout             = var.exposed_ports[count.index].health_check.timeout
      healthy_threshold   = var.exposed_ports[count.index].health_check.healthy_threshold
      unhealthy_threshold = var.exposed_ports[count.index].health_check.unhealthy_threshold
      matcher             = var.exposed_ports[count.index].health_check.matcher
    }
  }
  load_balancing_algorithm_type = var.load_balancing_algorithm_type
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb" "service_public_lb" {
  count                      = var.is_public && !var.disable_load_balancer ? length(local.lb_types) : 0
  name                       = "${var.service_name}-pu${count.index > 0 ? count.index + 1 : ""}-${var.color}"
  internal                   = false
  load_balancer_type         = local.lb_types[count.index]
  security_groups            = local.lb_types[count.index] == "application" ? var.public_lb_security_groups : null
  subnets                    = local.public_subnets
  tags                       = local.tags
  idle_timeout               = var.load_balancer_timeout
  enable_deletion_protection = var.del_protect
}

resource "aws_lb_listener" "public_lb_listener" {
  count = var.is_public && !var.disable_load_balancer ? length(local.lb_listener_ports) : 0
  load_balancer_arn = aws_lb.service_public_lb[
    local.lb_type_to_lb[
      local.protocol_to_load_balancer[
        local.lb_listener_protocols[count.index]
      ]
    ]
  ].arn
  port     = local.lb_listener_ports[count.index]
  protocol = local.lb_listener_protocols[count.index]
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.service_public_target_group[count.index].arn
  }
  certificate_arn = upper(local.lb_listener_protocols[count.index]) == "HTTPS" ? var.load_balancer_certificate_arn : null
}

resource "aws_security_group" "private_lb_security_group" {
  count       = !var.disable_load_balancer && length(var.private_lb_security_groups) == 0 && var.load_balancer_type == "application" && length(local.lb_listener_ports) > 0 ? 1 : 0
  name        = "ecs-${var.service_name}-allowed-traffic"
  description = "Automatically Generated by Terraform service module"
  vpc_id      = data.aws_vpc.service_vpc.id

  dynamic "ingress" {
    for_each = local.lb_listener_ports
    content {
      from_port   = ingress.value
      protocol    = "tcp"
      to_port     = ingress.value
      cidr_blocks = [data.aws_vpc.service_vpc.cidr_block]
    }
  }

  egress {
    from_port   = 0
    protocol    = -1
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# resource "aws_lb" "service_private_lb" {
#   count              = !var.disable_load_balancer ? length(local.lb_types) : 0
#   name               = "${var.service_name}-pr${count.index > 0 ? count.index + 1 : ""}-${var.color}"
#   internal           = true
#   load_balancer_type = local.lb_types[count.index]
#   security_groups = length(var.private_lb_security_groups) == 0 && local.lb_types[count.index] == "application" ? [
#     aws_security_group.private_lb_security_group[0].id
#   ] : var.private_lb_security_groups
#   subnets                    = local.private_subnets
#   tags                       = local.tags
#   idle_timeout               = var.load_balancer_timeout
#   enable_deletion_protection = var.del_protect
# }

# resource "aws_lb_listener" "private_lb_listener" {
#   count = !var.disable_load_balancer ? length(local.lb_listener_ports) : 0
#   load_balancer_arn = aws_lb.service_private_lb[
#     local.lb_type_to_lb[
#       local.protocol_to_load_balancer[
#         local.lb_listener_protocols[count.index]
#       ]
#     ]
#   ].arn
#   port     = local.lb_listener_ports[count.index]
#   protocol = local.lb_listener_protocols[count.index]
#   default_action {
#     type             = "forward"
#     target_group_arn = aws_lb_target_group.service_private_target_group[count.index].arn
#   }
#   certificate_arn = upper(local.lb_listener_protocols[count.index]) == "HTTPS" ? var.load_balancer_certificate_arn : null
# }

# resource "aws_lb_listener" "private_lb_listener_80_to_443" {
#   count             = local.redirect_80_443
#   load_balancer_arn = aws_lb.service_private_lb[0].arn
#   port              = 80
#   default_action {
#     type = "redirect"
#     redirect {
#       port        = 443
#       protocol    = "HTTPS"
#       status_code = "HTTP_301"
#     }
#   }
# }

resource "aws_lb_listener" "public_lb_listener_80_to_443" {
  count             = !var.disable_load_balancer && var.is_public ? local.redirect_80_443 : 0
  load_balancer_arn = aws_lb.service_public_lb[0].arn
  port              = 80
  default_action {
    type = "redirect"
    redirect {
      port        = 443
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_ecs_task_definition" "taskdef" {
  family                = var.service_name
  container_definitions = var.container_definitions
  task_role_arn         = aws_iam_role.task_definition_role.arn
  execution_role_arn    = try(aws_iam_role.task_execution_role[0].arn, null)
  cpu                   = var.task_def_cpu
  memory                = var.task_def_memory

  lifecycle {
    ignore_changes = [
      container_definitions
    ]
  }

  dynamic "volume" {
    for_each = var.volumes
    content {
      name = volume.value.name
      dynamic "docker_volume_configuration" {
        for_each = volume.value.docker_volume_configuration == null ? [] : [1]
        content {
          autoprovision = volume.value.docker_volume_configuration.auto_provision
          scope         = volume.value.docker_volume_configuration.scope
          driver        = volume.value.docker_volume_configuration.driver
          driver_opts   = volume.value.docker_volume_configuration.driver_opts
        }
      }
      host_path = volume.value.host_path
    }
  }
}

resource "aws_iam_role" "task_definition_role" {
  name               = "${var.service_name}-role"
  assume_role_policy = data.aws_iam_policy_document.ecs-assume-role-policy.json
}

resource "aws_iam_role_policy" "role_policies" {
  count  = length(var.policies)
  name   = var.policies[count.index].name
  policy = data.aws_iam_policy_document.policies[count.index].json
  role   = aws_iam_role.task_definition_role.id
}

# resource "aws_route53_record" "private_lb" {
#   count   = !var.disable_load_balancer && var.private_dns_zone_id != null && var.private_dns_zone_name != null && length(local.lb_listener_ports) > 0 ? 1 : 0
#   name    = "${var.service_name}.${var.private_dns_zone_name}"
#   type    = "CNAME"
#   zone_id = var.private_dns_zone_id
#   records = [aws_lb.service_private_lb[0].dns_name]
#   ttl     = 300
# }

resource "aws_route53_record" "public_lb" {
  count   = !var.disable_load_balancer && var.is_public && var.public_dns_zone_id != null && var.public_dns_zone_name != null && length(local.lb_listener_ports) > 0 ? 1 : 0
  name    = "${var.service_name}.${var.public_dns_zone_name}"
  type    = "CNAME"
  zone_id = var.public_dns_zone_id
  records = [aws_lb.service_public_lb[0].dns_name]
  ttl     = 300
}

resource "aws_ecr_repository" "ecr" {
  count                = var.create_ecr ? 1 : 0
  name                 = var.service_name
  image_tag_mutability = var.image_mutability

  image_scanning_configuration {
    scan_on_push = var.scan_on_push
  }
}
