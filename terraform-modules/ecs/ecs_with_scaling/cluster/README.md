# ecs/ecs_with_scaling/cluster

This module facilitates the creation of an ECS cluster.

The minimum set of variables that must be passed are:
- cluster_name
- instance_key_pair_name
- asg_subnets
- tags

This module creates (and manages) the following resources:
- Launch Configuration: Based on the instance key pair, user data and AMI ID configurations
- Auto Scaling Group: Based on the subnets, tags, cluster name, minimum and maximum configurations
- ECS Capacity Provider to be used with the cluster with the auto generated auto scaling group attached to it
- An IAM instance profile with ecsWithVolumeManagement policy to allow instances to manage ebs volumes

Capacity provider creation can be skipped with the _skip_capacity_provider_ flag set to _true_

The variables are well documented in _vars.tf_ file, but some default values are worth mentioning, because the end user will eventually want to change them:

- _cluster_minimum_size_ and _cluster_maximum_size_ = 1
- _cluster_target_usage_ = 100 (if the user wants to have some spare capacity, it must be reduced, then)
- _instance_type_ = t2.micro (can be changed if the computing requirements for the services are higher)
- _create_launch_configuration_ = true
- _launch_configuration_name_ = ""
  - In case there is an already created launch configuration to be used with this cluster, then the _create_launch_configuration_ variable can be set to false and this variable must be non empty
- _user_data_ = ""
  - The default value here is an empty string, but there is no way to set up an ECS cluster without setting an user data configuration. The user data must set the docker agent configuration into the ECS instances.
