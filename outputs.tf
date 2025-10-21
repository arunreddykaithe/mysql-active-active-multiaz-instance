# ========================================
# Outputs - Dynamic for 1-3 instances
# ========================================

# Group Replication UUID
output "group_replication_uuid" {
  description = "Group Replication UUID"
  value       = local.group_uuid
}

# VPC Information
output "region1_vpc_id" {
  description = "VPC ID for Region 1"
  value       = module.vpc_region1.vpc_id
}

output "region2_vpc_id" {
  description = "VPC ID for Region 2"
  value       = module.vpc_region2.vpc_id
}

# Region 1 RDS Endpoints (dynamic)
output "region1_rds_endpoints" {
  description = "All RDS instance endpoints in Region 1"
  value       = module.rds_region1[*].rds_endpoint
}

output "region1_rds_parameter_groups" {
  description = "All parameter group names in Region 1"
  value       = module.rds_region1[*].parameter_group_name
}

output "region1_rds_multi_az_status" {
  description = "Multi-AZ status for all instances in Region 1"
  value       = module.rds_region1[*].multi_az_enabled
}

# Region 2 RDS Endpoints (dynamic)
output "region2_rds_endpoints" {
  description = "All RDS instance endpoints in Region 2"
  value       = module.rds_region2[*].rds_endpoint
}

output "region2_rds_parameter_groups" {
  description = "All parameter group names in Region 2"
  value       = module.rds_region2[*].parameter_group_name
}

output "region2_rds_multi_az_status" {
  description = "Multi-AZ status for all instances in Region 2"
  value       = module.rds_region2[*].multi_az_enabled
}

# Connection Commands
output "connection_summary" {
  description = "MySQL connection commands for all instances"
  value = {
    region1 = [
      for i in range(var.region1_instance_count) :
      "mysql -h ${module.rds_region1[i].rds_endpoint} -u ${var.db_username} -p"
    ]
    region2 = [
      for i in range(var.region2_instance_count) :
      "mysql -h ${module.rds_region2[i].rds_endpoint} -u ${var.db_username} -p"
    ]
  }
}

# Summary Output
output "deployment_summary" {
  description = "Deployment summary"
  value = <<-EOT
==========================================
MySQL Multi-AZ Active-Active Deployment
==========================================

Region 1 (${var.region1}): ${var.region1_instance_count} Multi-AZ instance(s)
Region 2 (${var.region2}): ${var.region2_instance_count} Multi-AZ instance(s)
Total Primary Instances: ${var.region1_instance_count + var.region2_instance_count}

Each Multi-AZ instance includes:
  - 1 Primary (active in Group Replication)
  - 1 Standby (automatic failover)

Group Replication UUID: ${local.group_uuid}

Next steps:
  1. Run: ./scripts/setup_replication.sh
  2. Test: ./scripts/test_replication.sh
==========================================
EOT
}

# Project name for scripts
output "project_name" {
  description = "Project name"
  value       = var.project_name
}
