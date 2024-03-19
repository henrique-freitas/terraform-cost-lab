#!/bin/bash
echo 'ECS_DATADIR=/data
ECS_ENABLE_TASK_IAM_ROLE=true
ECS_ENABLE_TASK_IAM_ROLE_NETWORK_HOST=true
ECS_LOGFILE=/var/log/ecs-agent.log
ECS_LOGLEVEL=info
ECS_CLUSTER='${ecs_cluster}'
ECS_RESERVED_MEMORY=256
ECS_SELINUX_CAPABLE=true
ECS_BACKEND_HOST=
ECS_CONTAINER_STOP_TIMEOUT=120s
ECS_ENGINE_TASK_CLEANUP_WAIT_DURATION=15m
ECS_DISABLE_IMAGE_CLEANUP=false
ECS_IMAGE_CLEANUP_INTERVAL=${img_cleanup_interval}
ECS_IMAGE_PULL_BEHAVIOR=${img_pull_behaviour}
ECS_ENABLE_CONTAINER_METADATA=${enable_container_metadata}
ECS_AVAILABLE_LOGGING_DRIVERS=["json-file","syslog","gelf","journald","awslogs"]
ECS_ENGINE_AUTH_TYPE=docker' > /etc/ecs/ecs.config
docker plugin install rexray/ebs REXRAY_PREEMPT=true EBS_REGION=${region} --grant-all-permissions
