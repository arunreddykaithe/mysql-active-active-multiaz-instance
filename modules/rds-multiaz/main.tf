# ========================================
# Multi-AZ RDS Instance with Group Replication
# ========================================

# DB Parameter Group for Group Replication
resource "aws_db_parameter_group" "main" {
  name   = "${var.name_prefix}-pg"
  family = "mysql8.0"

  # Enable Group Replication
  parameter {
    name         = "rds.group_replication_enabled"
    value        = "1"
    apply_method = "pending-reboot"
  }

  # Enable custom DNS resolution
  parameter {
    name         = "rds.custom_dns_resolution"
    value        = "1"
    apply_method = "pending-reboot"
  }

  # Group Replication UUID
  parameter {
    name         = "group_replication_group_name"
    value        = var.group_replication_uuid
    apply_method = "pending-reboot"
  }

  # GTID mode
  parameter {
    name         = "gtid-mode"
    value        = "ON"
    apply_method = "pending-reboot"
  }

  # Enforce GTID consistency
  parameter {
    name         = "enforce_gtid_consistency"
    value        = "ON"
    apply_method = "pending-reboot"
  }

  # Binlog format
  parameter {
    name         = "binlog_format"
    value        = "ROW"
    apply_method = "immediate"
  }

  # Preserve commit order
  parameter {
    name         = "slave_preserve_commit_order"
    value        = "1"
    apply_method = "immediate"
  }

  # Start Group Replication on boot
  parameter {
    name         = "group_replication_start_on_boot"
    value        = "1"
    apply_method = "pending-reboot"
  }

  # Group seeds (will be updated by setup script)
  parameter {
    name         = "group_replication_group_seeds"
    value        = var.group_replication_seeds
    apply_method = "immediate"
  }

  # Enable binary logging functions
  parameter {
    name         = "log_bin_trust_function_creators"
    value        = "1"
    apply_method = "immediate"
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-parameter-group"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# Multi-AZ RDS Instance
resource "aws_db_instance" "main" {
  identifier = var.instance_identifier

  # Engine configuration
  engine         = "mysql"
  engine_version = var.engine_version
  instance_class = var.instance_class

  # Storage configuration
  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = var.storage_type
  storage_encrypted     = var.storage_encrypted

  # Multi-AZ configuration (creates automatic standby)
  multi_az = var.multi_az

  # Database configuration
  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  # Network configuration
  db_subnet_group_name   = var.db_subnet_group_name
  vpc_security_group_ids = [var.security_group_id]
  publicly_accessible    = var.publicly_accessible
  port                   = 3306

  # Parameter group
  parameter_group_name = aws_db_parameter_group.main.name

  # Backup configuration (REQUIRED for binary logging/Group Replication)
  backup_retention_period   = var.backup_retention_period
  backup_window             = var.backup_window
  maintenance_window        = var.maintenance_window
  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${var.instance_identifier}-final-snapshot"

  # Monitoring and logging
  enabled_cloudwatch_logs_exports = ["error", "general", "slowquery"]
  monitoring_interval             = var.monitoring_interval
  monitoring_role_arn             = var.monitoring_interval > 0 ? aws_iam_role.rds_monitoring[0].arn : null

  # Performance insights
  performance_insights_enabled          = var.performance_insights_enabled
  performance_insights_retention_period = var.performance_insights_enabled ? 7 : null

  # Deletion protection
  deletion_protection = var.deletion_protection

  # Auto minor version upgrade
  auto_minor_version_upgrade = var.auto_minor_version_upgrade

  # Apply changes immediately
  apply_immediately = true

  tags = merge(
    var.tags,
    {
      Name     = var.instance_identifier
      MultiAZ  = var.multi_az ? "enabled" : "disabled"
    }
  )

  lifecycle {
    ignore_changes = [
      password,
      final_snapshot_identifier
    ]
  }
}

# IAM Role for Enhanced Monitoring (if enabled)
resource "aws_iam_role" "rds_monitoring" {
  count = var.monitoring_interval > 0 ? 1 : 0

  name = "${var.name_prefix}-rds-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  count = var.monitoring_interval > 0 ? 1 : 0

  role       = aws_iam_role.rds_monitoring[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}
