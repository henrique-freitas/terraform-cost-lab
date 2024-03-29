locals {
  capacity_providers        = var.skip_capacity_provider ? [] : concat([aws_ecs_capacity_provider.ecs_capacity_provider.name], var.capacity_providers)
  launch_configuration_name = var.create_launch_configuration ? aws_launch_configuration.ecs_lc[0].name : var.launch_configuration_name
}

resource "aws_ecs_cluster" "ecs_cluster" {
  name               = var.cluster_name
  dynamic "setting" {
    for_each = var.cluster_settings
    content {
      name  = setting.key
      value = setting.value
    }
  }
  tags = local.tags
}

resource "aws_security_group" "instance_security_group" {
  count       = length(var.instance_security_groups) == 0 ? 1 : 0
  name        = "ecs-${var.cluster_name}-instance"
  description = "Automatically Generated by Terraform ecs/cluster module"
  vpc_id      = data.aws_subnet.subnet_info.vpc_id

  ingress {
    from_port   = 0
    protocol    = "tcp"
    to_port     = 65535
    cidr_blocks = [data.aws_vpc.vpc_info.cidr_block]
  }

  egress {
    from_port   = 0
    protocol    = -1
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_launch_configuration" "ecs_lc" {
  count                = var.create_launch_configuration ? 1 : 0
  name_prefix          = "ecs-${var.cluster_name}"
  image_id             = var.ami_id != "" ? var.ami_id : data.aws_ami.amazon_linux_ecs.id
  instance_type        = var.instance_type
  user_data            = var.user_data != "" ? var.user_data : data.template_file.ecs_user_data.rendered
  key_name             = var.instance_key_pair_name
  security_groups      = length(var.instance_security_groups) == 0 ? [aws_security_group.instance_security_group[0].id] : var.instance_security_groups
  iam_instance_profile = aws_iam_instance_profile.ecs_instance_profile.id

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [image_id]
  }
}

resource "aws_iam_role" "ecs_instance_profile_role" {
  name                  = "ecsInstance-${var.cluster_name}"
  assume_role_policy    = data.aws_iam_policy_document.ecs-instance-profile-assume-role-policy.json
  force_detach_policies = true
}

resource "aws_iam_role_policy" "ssm" {
  count  = var.add_ssm_policy ? 1 : 0
  policy = data.aws_iam_policy.ssm_policy.policy
  role   = aws_iam_role.ecs_instance_profile_role.id
}

resource "aws_iam_role_policy" "ecs_instance_profile_policies" {
  name   = "ecsWithVolumeManagement"
  policy = data.aws_iam_policy_document.ecs-instance-profile-policies.json
  role   = aws_iam_role.ecs_instance_profile_role.id
}

resource "aws_iam_instance_profile" "ecs_instance_profile" {
  name = "ecsInstance-${var.cluster_name}"
  role = aws_iam_role.ecs_instance_profile_role.name
}

resource "aws_autoscaling_group" "ecs_asg" {
  name                  = "ecs-${var.cluster_name}"
  max_size              = var.cluster_maximum_size
  min_size              = var.cluster_minimum_size
  max_instance_lifetime = var.cluster_maximum_instance_lifetime
  vpc_zone_identifier   = var.asg_subnets
  launch_configuration  = local.launch_configuration_name

  dynamic "tag" {
    for_each = local.tags
    content {
      key                 = tag.key
      propagate_at_launch = false
      value               = tag.value
    }
  }

  tag {
    key                 = "AmazonECSManaged"
    value               = ""
    propagate_at_launch = true
  }


  lifecycle {
    create_before_destroy = true
  }
  enabled_metrics       = var.asg_enabled_metrics
  protect_from_scale_in = var.scale_in_protection
}

resource "aws_ecs_capacity_provider" "ecs_capacity_provider" {
  name = "ecluster-${var.cluster_name}"

  auto_scaling_group_provider {
    auto_scaling_group_arn         = aws_autoscaling_group.ecs_asg.arn
    managed_termination_protection = var.scale_in_protection == true ? "ENABLED" : "DISABLED"

    managed_scaling {
      maximum_scaling_step_size = var.max_container_scale_size
      minimum_scaling_step_size = var.min_container_scale_size
      status                    = "ENABLED"
      target_capacity           = var.cluster_target_usage
    }
  }
}
