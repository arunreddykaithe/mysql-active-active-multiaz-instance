output "rds_endpoint" {
  description = "RDS instance endpoint (hostname only)"
  value       = aws_db_instance.main.address
}

output "rds_endpoint_full" {
  description = "RDS instance endpoint with port"
  value       = aws_db_instance.main.endpoint
}

output "rds_instance_id" {
  description = "RDS instance ID"
  value       = aws_db_instance.main.id
}

output "rds_arn" {
  description = "RDS instance ARN"
  value       = aws_db_instance.main.arn
}

output "rds_port" {
  description = "RDS instance port"
  value       = aws_db_instance.main.port
}

output "parameter_group_name" {
  description = "Parameter group name"
  value       = aws_db_parameter_group.main.name
}

output "rds_status" {
  description = "Status of the RDS instance"
  value       = aws_db_instance.main.status
}

output "rds_availability_zone" {
  description = "Availability zone of the primary instance"
  value       = aws_db_instance.main.availability_zone
}

output "multi_az_enabled" {
  description = "Whether Multi-AZ is enabled"
  value       = aws_db_instance.main.multi_az
}
