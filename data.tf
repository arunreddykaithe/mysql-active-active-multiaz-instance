# ========================================
# Data Sources
# ========================================

# Get available AZs in Region 1
data "aws_availability_zones" "region1" {
  provider = aws.region1
  state    = "available"
  
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

# Get available AZs in Region 2
data "aws_availability_zones" "region2" {
  provider = aws.region2
  state    = "available"
  
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

# Get current AWS region info
data "aws_region" "region1" {
  provider = aws.region1
}

data "aws_region" "region2" {
  provider = aws.region2
}

# Generate UUID for Group Replication if not provided
resource "random_uuid" "group_replication" {
  count = var.group_replication_group_name == "" ? 1 : 0
}

# Local values
locals {
  # Use provided UUID or generate new one
  group_uuid = var.group_replication_group_name != "" ? var.group_replication_group_name : random_uuid.group_replication[0].result
  
  # Common tags
  common_tags = merge(
    {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.additional_tags
  )
  
  # Region 1 AZs (take first 3)
  region1_azs = slice(data.aws_availability_zones.region1.names, 0, 3)
  
  # Region 2 AZs (take first 3)
  region2_azs = slice(data.aws_availability_zones.region2.names, 0, 3)
}
