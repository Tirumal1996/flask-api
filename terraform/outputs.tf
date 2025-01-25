output "flask_service_name" {
  value       = aws_ecs_service.flask_service.name
  description = "The name of the ECS service"
}

output "flask_service_cluster" {
  value       = aws_ecs_service.flask_service.cluster
  description = "The ID of the ECS cluster where the service is running"
}

output "flask_service_task_definition" {
  value       = aws_ecs_service.flask_service.task_definition
  description = "The ARN of the ECS task definition associated with the service"
}

output "flask_service_desired_count" {
  value       = aws_ecs_service.flask_service.desired_count
  description = "The desired count of tasks in the ECS service"
}

output "flask_service_launch_type" {
  value       = aws_ecs_service.flask_service.launch_type
  description = "The launch type of the ECS service"
}

output "flask_service_subnets" {
  value       = aws_ecs_service.flask_service.network_configuration.0.subnets
  description = "The IDs of the subnets in which the ECS service is running"
}

output "flask_service_security_groups" {
  value       = aws_ecs_service.flask_service.network_configuration.0.security_groups
  description = "The security group IDs associated with the ECS service"
}

# Output resources for verification
output "vpc_id" {
  value = aws_vpc.flask_vpc.id
}

output "public_subnet_id" {
  value = aws_subnet.public_subnet.id
}

output "private_subnet_id" {
  value = aws_subnet.private_subnet.id
}

output "internet_gateway_id" {
  value = aws_internet_gateway.flask_igw.id
}

output "security_group_id" {
  value = aws_security_group.flask_api_sg.id
}