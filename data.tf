data "aws_vpcs" "selected_vpc_id" {
  count = var.vpc_id == null? 1: 0
  tags = {
    Name = "Lab-VPC"
  }
}

data "aws_vpc" "main_vpc" {
  id = local.vpc_id
}

data "aws_subnets" "public_subnets" {
  filter {
    name = "tag:Name"
    values = ["lab-1a", "lab-1b"]
  }
}

data "template_file" "cost_container_definitions" {
  template = file(var.container_definitions_path)
  vars = {
    cpu = var.cost-lab_cpu
    memory = var.cost-lab_memory
    service_name = "lab-cost"
    docker_image = "${module.service_cost.docker_repository_url}:latest"
    exposed_ports = jsonencode([
    for p in var.lab_exposed_ports :
    {
      containerPort = p.port,
      protocol = p.protocol == "udp"? "udp": "tcp"
    }])
    environment = jsonencode([])
    secrets = jsonencode([])
  }
}