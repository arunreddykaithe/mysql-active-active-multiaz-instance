output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

output "vpc_cidr_block" {
  description = "VPC CIDR block (alias)"
  value       = aws_vpc.main.cidr_block
}

output "subnet_ids" {
  description = "IDs of the subnets"
  value       = aws_subnet.main[*].id
}

output "public_subnet_ids" {
  description = "List of public subnet IDs (alias for ProxySQL)"
  value       = aws_subnet.main[*].id
}

output "security_group_id" {
  description = "ID of the RDS security group"
  value       = aws_security_group.rds.id
}

output "db_subnet_group_name" {
  description = "Name of the DB subnet group"
  value       = aws_db_subnet_group.main.name
}

output "route_table_id" {
  description = "ID of the main route table"
  value       = aws_route_table.main.id
}

output "internet_gateway_id" {
  description = "ID of the internet gateway"
  value       = aws_internet_gateway.main.id
}