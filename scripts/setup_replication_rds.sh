#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo "========================================="
echo "MySQL Multi-AZ Active-Active Setup"
echo "========================================="
echo ""

# Check for Terraform outputs
if [ ! -f "terraform.tfstate" ]; then
    log_error "terraform.tfstate not found. Run 'terraform apply' first."
    exit 1
fi

# Get configuration from Terraform
log_info "Reading Terraform outputs..."

REGION1=$(terraform output -json region1_rds_endpoints | jq -r '.[0]' 2>/dev/null | awk -F'.' '{print $(NF-3)}' || echo "us-east-2")
REGION2=$(terraform output -json region2_rds_endpoints | jq -r '.[0]' 2>/dev/null | awk -F'.' '{print $(NF-3)}' || echo "us-west-2")

# Get all RDS endpoints dynamically
REGION1_ENDPOINTS=($(terraform output -json region1_rds_endpoints | jq -r '.[]'))
REGION2_ENDPOINTS=($(terraform output -json region2_rds_endpoints | jq -r '.[]'))

REGION1_COUNT=${#REGION1_ENDPOINTS[@]}
REGION2_COUNT=${#REGION2_ENDPOINTS[@]}
TOTAL_COUNT=$((REGION1_COUNT + REGION2_COUNT))

log_info "Detected configuration:"
log_info "  Region 1 ($REGION1): $REGION1_COUNT instances"
log_info "  Region 2 ($REGION2): $REGION2_COUNT instances"
log_info "  Total instances: $TOTAL_COUNT"
echo ""

# Get Group Replication UUID
GROUP_UUID=$(terraform output -raw group_replication_uuid)
log_info "Group Replication UUID: $GROUP_UUID"

# Get project name from terraform
project_name=$(terraform output -raw project_name 2>/dev/null || echo "mysql-multiaz-activeactive")

echo ""

# Prompt for passwords
read -s -p "Enter database password: " DB_PASSWORD
echo ""
read -s -p "Enter Group Replication user password: " GR_PASSWORD
echo ""
echo ""

# Step 1: Build group seeds list
log_info "Step 1: Building Group Replication seeds list..."

ALL_SEEDS=""
for endpoint in "${REGION1_ENDPOINTS[@]}" "${REGION2_ENDPOINTS[@]}"; do
    ALL_SEEDS="${ALL_SEEDS}${endpoint}:3306,"
done
ALL_SEEDS=${ALL_SEEDS%,}  # Remove trailing comma

log_success "Group seeds: $ALL_SEEDS"
echo ""

# Step 2: Update parameter groups with seeds
log_info "Step 2: Updating parameter groups with group seeds..."

update_parameter_group() {
    local pg_name=$1
    local region=$2

    aws rds modify-db-parameter-group \
        --db-parameter-group-name "$pg_name" \
        --parameters "[{\"ParameterName\":\"group_replication_group_seeds\",\"ParameterValue\":\"$ALL_SEEDS\",\"ApplyMethod\":\"immediate\"}]" \
        --region "$region"

    log_success "  Updated: $pg_name"
}

# Get all parameter group names and update them
for i in $(seq 0 $((REGION1_COUNT-1))); do
    PG_NAME=$(terraform output -json region1_rds_parameter_groups | jq -r ".[$i]")
    update_parameter_group "$PG_NAME" "$REGION1"
done

for i in $(seq 0 $((REGION2_COUNT-1))); do
    PG_NAME=$(terraform output -json region2_rds_parameter_groups | jq -r ".[$i]")
    update_parameter_group "$PG_NAME" "$REGION2"
done

log_success "All parameter groups updated"
echo ""

# Step 3: Wait for parameter changes to propagate
log_info "Step 3: Waiting for parameter changes to propagate..."
sleep 30
log_success "Parameters propagated"
echo ""

# Step 4: Bootstrap Group Replication on first instance (Region 1, Instance 1)
log_info "Step 4: Bootstrapping Group Replication on ${REGION1_ENDPOINTS[0]}..."

mysql -h "${REGION1_ENDPOINTS[0]}" -u admin -p"$DB_PASSWORD" --ssl-mode=REQUIRED << EOSQL
CALL mysql.rds_set_configuration('binlog retention hours', 168);
CALL mysql.rds_group_replication_create_user('$GR_PASSWORD');
CALL mysql.rds_group_replication_set_recovery_channel('$GR_PASSWORD');
CALL mysql.rds_group_replication_start(1);
SELECT 'Group Replication bootstrapped on ${REGION1_ENDPOINTS[0]}' AS Status;
EOSQL

if [ $? -eq 0 ]; then
    log_success "Bootstrap complete on ${REGION1_ENDPOINTS[0]}"
else
    log_error "Failed to bootstrap Group Replication"
    exit 1
fi

sleep 15
echo ""

# Step 5: Join remaining instances to the group
log_info "Step 5: Joining remaining instances to the group..."

join_instance() {
    local endpoint=$1
    local instance_name=$2

    log_info "  Joining: $instance_name ($endpoint)"

    mysql -h "$endpoint" -u admin -p"$DB_PASSWORD" --ssl-mode=REQUIRED << EOSQL
CALL mysql.rds_set_configuration('binlog retention hours', 168);
CALL mysql.rds_group_replication_create_user('$GR_PASSWORD');
CALL mysql.rds_group_replication_set_recovery_channel('$GR_PASSWORD');
CALL mysql.rds_group_replication_start(0);
SELECT '$instance_name joined Group Replication' AS Status;
EOSQL

    if [ $? -eq 0 ]; then
        log_success "  Joined: $instance_name"
    else
        log_error "  Failed to join $instance_name"
        exit 1
    fi

    sleep 10
}

instance_num=2
# Join remaining Region 1 instances
for i in $(seq 1 $((REGION1_COUNT-1))); do
    join_instance "${REGION1_ENDPOINTS[$i]}" "Region 1 Instance $((i+1))"
    ((instance_num++))
done

# Join all Region 2 instances
for i in $(seq 0 $((REGION2_COUNT-1))); do
    join_instance "${REGION2_ENDPOINTS[$i]}" "Region 2 Instance $((i+1))"
    ((instance_num++))
done

echo ""

# Step 6: Verify cluster status
log_info "Step 6: Verifying Group Replication status..."
echo ""

echo "Checking from ${REGION1_ENDPOINTS[0]}:"
mysql -h "${REGION1_ENDPOINTS[0]}" -u admin -p"$DB_PASSWORD" --ssl-mode=REQUIRED << EOSQL
SELECT
    MEMBER_HOST,
    MEMBER_PORT,
    MEMBER_STATE,
    MEMBER_ROLE
FROM performance_schema.replication_group_members
ORDER BY MEMBER_HOST;
EOSQL

echo ""

# Step 7: Test replication
log_info "Step 7: Testing replication across all instances..."

mysql -h "${REGION1_ENDPOINTS[0]}" -u admin -p"$DB_PASSWORD" --ssl-mode=REQUIRED << EOSQL
CREATE DATABASE IF NOT EXISTS test_replication;
USE test_replication;
CREATE TABLE IF NOT EXISTS test_table (
    id INT AUTO_INCREMENT PRIMARY KEY,
    instance VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
INSERT INTO test_table (instance) VALUES ('${REGION1_ENDPOINTS[0]}');
EOSQL

sleep 3

log_info "Verifying data on last instance (${REGION2_ENDPOINTS[$((REGION2_COUNT-1))]})..."
mysql -h "${REGION2_ENDPOINTS[$((REGION2_COUNT-1))]}" -u admin -p"$DB_PASSWORD" --ssl-mode=REQUIRED << EOSQL
USE test_replication;
SELECT * FROM test_table;
EOSQL

echo ""
log_success "========================================="
log_success "Setup Complete!"
log_success "========================================="
echo ""
log_info "Summary:"
log_info "  - $TOTAL_COUNT instances in Group Replication"
log_info "  - All instances should show MEMBER_STATE='ONLINE'"
log_info "  - Test database created and replicated"
echo ""
log_info "Connection commands:"
for endpoint in "${REGION1_ENDPOINTS[@]}" "${REGION2_ENDPOINTS[@]}"; do
    log_info "  mysql -h $endpoint -u admin -p --ssl-mode=REQUIRED"
done
echo ""
log_info "Next steps:"
log_info "  1. Verify cluster status:"
log_info "     SELECT * FROM performance_schema.replication_group_members;"
log_info "  2. All instances can accept writes!"
echo ""
