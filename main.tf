terraform {
  backend "s3"{
  }
}

provider "aws" {
  region = "eu-north-1"
}


locals {
  asg_subnets = length(var.asg_subnets) > 0? var.asg_subnets: data.aws_subnets.public_subnets.ids
  vpc_id = var.vpc_id == null? tolist(data.aws_vpcs.selected_vpc_id[0].ids)[0]: var.vpc_id
  
  
}

module "ecs_with_scaling" {
  source = "./terraform-modules/ecs/ecs_with_scaling/cluster"
  skip_capacity_provider = var.skip_capacity_provider
  cluster_name = "cost-lab-test"
  tags = {}
  instance_type = var.asg_instance_type
  asg_subnets = local.asg_subnets
  instance_key_pair_name = var.instance_key_pair_name
  cluster_maximum_size = var.asg_maximum_capacity
  cluster_minimum_size = var.asg_minimum_capacity
  
}

module "service_cost" {
  source = "./terraform-modules/ecs/service"
  is_public = true
  container_definitions = jsonencode([
    {
      name      = "cost_lab"
      image     = "cost_lab"
      cpu       = 10
      memory    = 512
      essential = true
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
        }
      ]
    }
  ])
  ecs_cluster = module.ecs_with_scaling.cluster_name
  exposed_ports = var.lab_exposed_ports
  ordered_placement_strategies = []
  private_dns_zone_id = null
  private_dns_zone_name = null
  service_desired_count = 1
  min_tasks = 1
  max_tasks = 1
  create_ecr = true
  service_name = "cost-lab"
  task_def_cpu = 500
  task_def_memory = 500
  volumes = []
  vpc_id = local.vpc_id
  load_balancer_timeout = 30
  image_mutability = "MUTABLE"
  public_lb_security_groups = []
  load_balancer_custom_ports = var.cost-lab_lb_listener_ports
  capacity_provider_strategies = [{
    capacity_provider = module.ecs_with_scaling.capacity_provider_name
    weight = 100
    base = 1
    
  }]
  policies = []
}