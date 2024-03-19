variable "cluster_name" {
  description = "Name of the cluster"
}

variable "instance_key_pair_name" {
  description = "name of the key pair previously used in AWS. This will be set as the key pair in every EC2 tht belongs to the ASG"
}

variable "asg_subnets" {
  description = "The subnets where the EC2 instances should reside"
  type        = list(string)
}

variable "tags" {
  description = "Tags to assign with the cluster and propagate to the EC2 instances"
  type        = map(string)
}

variable "skip_capacity_provider" {
  description = "Terraform has an issue while creating a new cluster along with a capacity provider. This switch allows to create the cluster without the capacity provider (externally setting this to true) and add it on a second run (leaving it false)"
  default     = false
}

variable "cluster_settings" {
  description = "List of cluster settings to be applied"
  type        = map(string)
  default     = {}
}

variable "capacity_providers" {
  description = "List of capacity providers"
  type        = list(string)
  default     = []
}

variable "cluster_minimum_size" {
  description = "Minimum size the cluster should assume"
  default     = 1
}

variable "cluster_maximum_size" {
  description = "Maximum number of EC2 instances the cluster can escalate to"
  default     = 1
}

variable "cluster_maximum_instance_lifetime" {
  description = "The maximum amount of time, in seconds, that an instance can be in service"
  type        = number
  default     = 0
}

variable "cluster_target_usage" {
  description = "ECS capacity provider will scale the cluster to have a resource usage closest possible to this value (1-100)"
  default     = 100
}

variable "min_container_scale_size" {
  description = "Minimum number of containers that can be scaled (in or out) at a time"
  default     = 1
}

variable "max_container_scale_size" {
  description = "Maximum number of containers that can be scaled (in or out) at a time"
  default     = 10000
}

variable "ami_id" {
  description = "ID of the AMI to use in the machines inside the ASG (configured via Launch Configuration). When omitted, it should use latest amazon linux ecs optimized"
  default     = ""
}

variable "instance_type" {
  description = "Sizing of the instances in the cluster"
  default     = "t2.micro"
}

variable "create_launch_configuration" {
  type        = bool
  description = "Create the launch configuration or use an external one instead"
  default     = true
}

variable "launch_configuration_name" {
  description = "Name of the LC to use in the Auto Scaling Group. If omitted, a new LC is created"
  default     = ""
}

variable "user_data" {
  description = "Initialization script for EC2. If omitted, a default one will be used instead (only configuring ECS agent)"
  default     = ""
}

variable "instance_security_groups" {
  description = "IDs of the security groups that should be attached to the instances of the ASG"
  default     = []
}

variable "asg_enabled_metrics" {
  description = "The list of metrics that should be enabled for collection at cloudwatch"
  default = [
    "GroupDesiredCapacity", "GroupInServiceCapacity", "GroupPendingCapacity", "GroupMinSize", "GroupMaxSize",
    "GroupInServiceInstances", "GroupPendingInstances", "GroupStandbyInstances", "GroupStandbyCapacity",
    "GroupTerminatingCapacity", "GroupTerminatingInstances", "GroupTotalCapacity", "GroupTotalInstances"
  ]
}

variable "scale_in_protection" {
  type        = bool
  description = "Whether to protect instances to scale in and let ECS manage what instances to terminate"
  default     = null
}

variable "enable_container_metadata" {
  type        = bool
  description = "Enable container metadata feature in ECS Agent"
  default     = false
}

variable "add_ssm_policy" {
  type        = bool
  description = "Add SSM policy to allow instance to be managed via Session Manager"
  default     = false
}

variable "ecs_agent_img_cleanup_interval_hours" {
  type        = number
  description = "The time to cleanup unused images in hours (ECS_IMAGE_CLEANUP_INTERVAL setting)"
  default     = 24
}

variable "ecs_agent_img_pull_behaviour" {
  description = "The ECS_IMAGE_PULL_BEHAVIOR configuration of the ECS Agent. The ECS Agent documentation has the possible values that can be entered here"
  default     = "prefer-cached"
}
