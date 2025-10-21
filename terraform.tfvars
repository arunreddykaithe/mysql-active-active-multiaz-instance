# ========================================
# MySQL Multi-AZ Active-Active Configuration
# ========================================

environment  = "production"
project_name = "mysql-multiaz-activeactive"

# AWS Regions
region1 = "us-east-2"
region2 = "us-west-2"

# ========================================
# FLEXIBILITY: How many instances per region?
# ========================================
# Each instance is Multi-AZ (primary + standby)
# Options: 1, 2, or 3 instances per region

region1_instance_count = 2  # 2 Multi-AZ instances in Region 1
region2_instance_count = 2  # 2 Multi-AZ instances in Region 2

# This creates:
# - 2 primaries + 2 standbys in Region 1
# - 2 primaries + 2 standbys in Region 2
# - Total: 4 active instances in Group Replication

# Examples of other configurations:
# - Minimal: region1_instance_count = 1, region2_instance_count = 1
# - Maximum: region1_instance_count = 3, region2_instance_count = 3

# ========================================
# Network Configuration
# ========================================

region1_vpc_cidr = "10.10.0.0/24"  # 256 IPs for Region 1
region2_vpc_cidr = "10.11.0.0/24"  # 256 IPs for Region 2

region1_subnet_cidrs = ["10.10.0.0/27", "10.10.0.32/27", "10.10.0.64/27"]
region2_subnet_cidrs = ["10.11.0.0/27", "10.11.0.32/27", "10.11.0.64/27"]

# ========================================
# RDS Configuration
# ========================================

db_instance_class    = "db.t3.medium"  # 2 vCPU, 4GB RAM (~$60/mo per instance)
db_allocated_storage = 100              # GB
db_engine_version    = "8.0.39"         # Must be 8.0.35+

# Database credentials
db_username = "admin"
db_password = "H&ckth3DbtoHac53v3riT#in4"  # ⚠️ CHANGE THIS!

# Backup configuration (required for Group Replication)
db_backup_retention_period = 7  # Days

# ========================================
# Multi-AZ Configuration
# ========================================

multi_az = true  # Enable automatic standby in different AZ

# ========================================
# Security Configuration
# ========================================

db_publicly_accessible = true  # Set false for production

# Allowed CIDR blocks for MySQL access
# ⚠️ For production, restrict to your IP or VPN!
allowed_cidr_blocks = ["0.0.0.0/0"]  # INSECURE - testing only!

# ========================================
# Deletion Protection
# ========================================

skip_final_snapshot = true  # ⚠️ Set to false for production!

# ========================================
# Group Replication
# ========================================

group_replication_group_name = ""  # Auto-generate UUID

# ========================================
# Tags
# ========================================

additional_tags = {
  Owner       = "DevOps Team"
  CostCenter  = "WiFi"
  Department  = "CP"
  Application = "MySQL-Cluster"
}

# ========================================
# COST ESTIMATES (with above configuration)
# ========================================
# 
# With region1_instance_count = 2, region2_instance_count = 2:
#
# Region 1:
#   - 2x db.t3.medium Multi-AZ @ ~$120/mo each = $240
# Region 2:
#   - 2x db.t3.medium Multi-AZ @ ~$120/mo each = $240
# Networking:
#   - VPC Peering + Data Transfer = ~$20
#
# TOTAL: ~$500/month
#
# To reduce costs:
#   - Use region1_instance_count = 1, region2_instance_count = 1 (~$260/mo)
#   - Use smaller instance: db.t3.small (~$60/mo per Multi-AZ)
#
# To increase capacity:
#   - Use region1_instance_count = 3, region2_instance_count = 3 (~$740/mo)
#   - Use larger instance: db.r5.large (~$350/mo per Multi-AZ)
