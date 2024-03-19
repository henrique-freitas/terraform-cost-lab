output "cluster_arn" {
  value = aws_ecs_cluster.ecs_cluster.arn
}

output "cluster_name" {
  //The name cannot be simply put into the value, because the name parameter is available before the resource is
  // actually created. Using the ARN into a transformation function forces terraform to firstly create the resource
  // and only after created exports the cluster name
  value = split(" ", "${aws_ecs_cluster.ecs_cluster.name} ${aws_ecs_cluster.ecs_cluster.arn}")[0]
}

output "capacity_provider_name" {
  value = aws_ecs_capacity_provider.ecs_capacity_provider.name
}

output "launch_configuration_name" {
  value = local.launch_configuration_name
}
