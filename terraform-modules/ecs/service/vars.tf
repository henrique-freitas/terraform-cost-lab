variable "container_definitions" {
  description = "Path to file containing the container definitions"
}

variable "service_name" {
  description = "The family name"
}

variable "ecs_cluster" {
  description = "The ECS cluster name"
}

variable "load_balancer_timeout" {
  description = "The timeouts to apply to the load balancers"
  default     = 60
}

variable "capacity_provider_strategies" {
  description = "The settings of the capacity provider strategy. See AWS the documentation for more info."
  type = list(object({
    capacity_provider = string
    weight            = number
    base              = number
  }))
  default = []
}

variable "service_desired_count" {
  description = "The desired number of active tasks for the service"
}

variable "task_def_cpu" {
  description = "CPU limit to the task"
}

variable "task_def_memory" {
  description = "Memory limit to the task"
}

variable "volumes" {
  type = list(object({
    name = string
    docker_volume_configuration = object({
      auto_provision = bool
      scope          = string
      driver         = string
      driver_opts    = map(string)
    })
    host_path = string
  }))
}

variable "policies" {
  description = "Definition of the policies to be part of the role automatically created to the task"
  type = list(object({
    name = string
    permissions = list(object({
      actions   = list(string)
      resources = list(string)
    }))
  }))
}

variable "service_placement_constraints" {
  description = "Definition of the constraints to place the service"
  type = list(object({
    type       = string
    expression = string
  }))
  default = []
}

variable "ordered_placement_strategies" {
  description = "AWS Order Placement Strategies"
  type = list(object({
    type  = string
    field = string
  }))
}

variable "container_port" {
  description = "The port which the container runs on"
  default     = 8080
}

variable "image_mutability" {
  description = "Whether the images are mutable or not"
  default     = "IMMUTABLE"
}

variable "scan_on_push" {
  description = "Whether to scan or not an image when pushing"
  default     = true
}

variable "create_ecr" {
  description = "Allow or not the creation of a ECR repo for this service"
  default     = true
}

variable "exposed_ports" {
  type = list(object({
    protocol = string
    port     = number
    health_check = object({
      interval            = number
      path                = string
      protocol            = string
      timeout             = number
      healthy_threshold   = number
      unhealthy_threshold = number
      matcher             = string
    })
  }))
  description = "The ports to be exposed in the load balancers"
}

variable "load_balancer_custom_ports" {
  description = "By default, the lb uses in its listeners the same ports as specified in exposed_ports. If this is not desirable, custom ports can be defined here. They should be in the same sequence as their respective counter parts in exposed_ports"
  type = list(object({
    port     = number
    protocol = string
  }))
  default = []
}

variable "load_balancer_certificate_arn" {
  description = "ARN of the certificates to be used in HTTPS ports"
  default     = null
}

variable "service_protocol" {
  description = "The service protocol"
  default     = "HTTP"
}

variable "load_balancer_type" {
  description = "Application or network"
  default     = "application"
}

variable "vpc_id" {
  description = "VPC id where the load balancer should stay"
}

variable "public_subnets" {
  type        = list(string)
  description = "IDs of the subnets where the public load balancers should be placed"
  default     = []
}

variable "private_subnets" {
  type        = list(string)
  description = "IDs of the subnets where the private load balancers should be placed"
  default     = []
}

variable "color" {
  description = "The service color (blue, green, etc)"
  default     = "blue"
}

variable "is_public" {
  description = "Whether the service is public or private"
  default     = false
}

variable "tags" {
  description = "Tags"
  default     = {}
}

variable "private_lb_security_groups" {
  description = "Security group ids to attach to private LB"
  type        = list(string)
  default     = []
}

variable "public_lb_security_groups" {
  description = "Security group ids to attach to public LB"
  type        = list(string)
  default     = []
}

variable "min_tasks" {
  type        = number
  description = "Minimum number of tasks that should be available"
  default     = 0
}

variable "max_tasks" {
  type        = number
  description = "Minimum number of tasks that should be available"
  default     = 0
}

variable "default_scaling_configuration" {
  type = object({
    in_cooldown  = number
    out_cooldown = number
    thresholds = list(
      object({
        metric     = string
        out_target = number
        in_target  = number
        period     = number
        periods    = number
      })
    )
  })
  description = "Default and basic scaling configuration"
  default = {
    in_cooldown  = 60
    out_cooldown = 60
    thresholds = [
      {
        out_target = 80
        in_target  = 40
        metric     = "CPUUtilization"
        period     = 60
        periods    = 2
      }
    ]
  }
}

variable "scaling_custom_configuration" {
  description = "User defined scaling configuration"
  type = object({
    in_cooldown  = number
    out_cooldown = number
    thresholds = list(
      object({
        metric     = string
        out_target = number
        in_target  = number
        period     = number
        periods    = number
      })
    )
  })
  default = null
}

variable "private_dns_zone_name" {
  description = "DNS name of the zone"
  default     = null
}

variable "private_dns_zone_id" {
  description = "DNS zone ID"
  default     = null
}

variable "public_dns_zone_name" {
  description = "DNS name of the zone"
  default     = null
}

variable "public_dns_zone_id" {
  description = "DNS zone ID"
  default     = null
}

variable "del_protect" {
  type        = bool
  description = "Enable deletion protection for LB"
  default     = true
}

variable "target_group_deregistration_delay" {
  type        = number
  description = "Set a default target deregistration delay to all target groups belonging to this service"
  default     = 0
}

variable "create_secrets_role" {
  type        = bool
  description = "If there are secrets in the service environment, a role will automatically created giving the task enough permissions to reveal them"
  default     = false
}

variable "disable_load_balancer" {
  type        = bool
  description = "This disables load balancing in this service out of the box. But external load balancing still can be defined with target_group_arns"
  default     = false
}

variable "target_group_arns" {
  type    = list(string)
  default = []
}

variable "load_balancing_algorithm_type" {
  description = "The routing algorithm to be used to route connections among targets. When null, assumes round robin"
  default     = null
}

variable "disable_scaling" {
  type        = bool
  description = "Explicitly disable scaling (but maintaining minimum and maximum configuration)"
  default     = false
}

variable "task_execution_role_random_name" {
  type        = bool
  description = "Indicates if the task_execution_role should be created with a random name"
  default     = true
}

variable "scheduling_strategy" {
  description = "The Scheduling Strategy to use. Daemon or Replica. In almost all cases this must stay undefined"
  default     = null
}
