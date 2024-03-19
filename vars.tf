variable "vpc_id" {
  description = "The vpc ID"
  default = null
}

variable "asg_minimum_capacity" {
  description = "Minimum number of instances into the ASG"
  default = 1
}

variable "asg_maximum_capacity" {
  description = "Maximum number of instances into the ASG"
  default = 1
}

variable "asg_subnets" {
  type = list(string)
  description = "The list of subnets to provision the auto scaling group on. Private subnets in the given vpc_id are used if omitted"
  default = []
}

variable "skip_capacity_provider" {
  description = "Flag to skip the capacity provider because terraform fails to create the cluster on the first run"
  default = false
}


variable "container_definitions_path" {
  description = "Path to container definitions file"
  default = "files/container_definitions.json.tpl"
}

variable "ecs_cluster_name" {
  description = "The cluster name"
  default = "cost-lab"
}

variable "asg_instance_type" {
  description = "The instance to be present into the cluster"
  default = "t3.micro"
}

variable "instance_key_pair_name" {
  description = "The key pair defined here will be used into the EC2s instances from the ASG"
  default = "cost-lab-prod"
}

variable "cost-lab_service_name" {
  default = "cost-lab"
}

variable "cost-lab_cpu" {
  default = 500
}

variable "cost-lab_memory" {
  default = 500
}

variable "cost-lab_lb_listener_ports" {
  description = "Override the exposed ports into the listeners"
  type = list(object({
    port = number
    protocol = string
  }))
  default = [
    {
      port = 443
      protocol = "HTTPS"
    }
  ]
}

variable "lab_exposed_ports" {
  type = list(object({
    protocol = string
    port     = number
    health_check = object({
      interval = number
      path = string
      protocol = string
      timeout = number
      healthy_threshold = number
      unhealthy_threshold = number
      matcher = string
    })
  }))
  default = [{
    protocol = "HTTP"
    port = 3000
    health_check = {
      interval = 30
      path = "/"
      protocol = "http"
      timeout = 10
      healthy_threshold = 2
      unhealthy_threshold = 2
      matcher = "302,200"
    }
  }]
}

variable "cost-lab_security_group" {
  description = "cost-lab Security group"
  type = object({
    name = string
    ingress_rules = list(object({
      port = string
      cidrs = list(string)
      protocol = string
    }))
  })
  default = {
    name = "cost-lab_allowed_traffic"
    ingress_rules = [
      {
        port = 80
        protocol = "TCP"
        cidrs = ["0.0.0.0/0"]
      },
      {
        port = 443
        protocol = "TCP"
        cidrs = ["0.0.0.0/0"]
      }
    ]
  }
}