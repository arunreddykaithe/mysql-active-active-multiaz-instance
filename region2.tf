# ========================================
# Region 2: US-WEST-2
# Flexible 1-3 Multi-AZ RDS Instances
# ========================================

module "vpc_region2" {
  source = "./modules/vpc"

  providers = {
    aws = aws.region2
  }

  name_prefix             = "${var.project_name}-${var.region2}"
  vpc_cidr                = var.region2_vpc_cidr
  subnet_cidrs            = var.region2_subnet_cidrs
  availability_zones      = local.region2_azs
  peer_vpc_cidr           = var.region1_vpc_cidr
  allowed_cidr_blocks     = var.allowed_cidr_blocks
  map_public_ip_on_launch = var.db_publicly_accessible

  tags = merge(
    local.common_tags,
    {
      Region = var.region2
    }
  )
}

# Dynamic RDS Instances - Create 1, 2, or 3 based on variable
module "rds_region2" {
  source = "./modules/rds-multiaz"
  count  = var.region2_instance_count

  providers = {
    aws = aws.region2
  }

  name_prefix          = "${var.project_name}-${var.region2}-${count.index + 1}"
  instance_identifier  = "${var.project_name}-${var.region2}-${count.index + 1}"
  engine_version       = var.db_engine_version
  instance_class       = var.db_instance_class
  allocated_storage    = var.db_allocated_storage
  db_username          = var.db_username
  db_password          = var.db_password
  db_subnet_group_name = module.vpc_region2.db_subnet_group_name
  security_group_id    = module.vpc_region2.security_group_id
  publicly_accessible  = var.db_publicly_accessible

  multi_az                = var.multi_az
  backup_retention_period = var.db_backup_retention_period
  skip_final_snapshot     = var.skip_final_snapshot

  group_replication_uuid  = local.group_uuid
  group_replication_seeds = ""  # Will be updated by setup script

  tags = merge(
    local.common_tags,
    {
      Region   = var.region2
      Instance = count.index + 1
    }
  )

  depends_on = [module.vpc_region2]
}
