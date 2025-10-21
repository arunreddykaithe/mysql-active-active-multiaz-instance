#!/bin/bash

# ========================================
# MySQL Multi-AZ Active-Active Test Script
# Tests replication across all instances
# ========================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }
log_error() { echo -e "${RED}[✗]${NC} $1"; }

echo "========================================="
echo "MySQL Multi-AZ Active-Active Tests"
echo "========================================="
echo ""

# Check for Terraform state
if [ ! -f "terraform.tfstate" ]; then
    log_error "terraform.tfstate not found. Run 'terraform apply' first."
    exit 1
fi

# Get endpoints
REGION1_ENDPOINTS=($(terraform output -json region1_rds_endpoints | jq -r '.[]'))
REGION2_ENDPOINTS=($(terraform output -json region2_rds_endpoints | jq -r '.[]'))
ALL_ENDPOINTS=("${REGION1_ENDPOINTS[@]}" "${REGION2_ENDPOINTS[@]}")

TOTAL_COUNT=${#ALL_ENDPOINTS[@]}
LAST_R1_IDX=$((${#REGION1_ENDPOINTS[@]}-1))
LAST_R2_IDX=$((${#REGION2_ENDPOINTS[@]}-1))

log_info "Testing $TOTAL_COUNT instances:"
log_info "  Region 1: ${#REGION1_ENDPOINTS[@]} instances"
log_info "  Region 2: ${#REGION2_ENDPOINTS[@]} instances"
echo ""

# Prompt for password
read -s -p "Enter database password: " DB_PASSWORD
echo ""
echo ""

# Test 1: Check cluster membership
echo "Test 1: Cluster Membership"
echo "-----------------------------"
log_info "Checking all instances are in the cluster..."

ONLINE_COUNT=$(mysql -h "${ALL_ENDPOINTS[0]}" -u admin -p"$DB_PASSWORD" --ssl-mode=REQUIRED -N 2>/dev/null <<EOF
SELECT COUNT(*) FROM performance_schema.replication_group_members 
WHERE MEMBER_STATE='ONLINE';
EOF
)

if [ "$ONLINE_COUNT" -eq "$TOTAL_COUNT" ]; then
    log_success "All $TOTAL_COUNT instances are ONLINE in Group Replication"
else
    log_error "Only $ONLINE_COUNT/$TOTAL_COUNT instances are ONLINE"
    
    # Show which instances are not online
    log_info "Checking individual member status..."
    mysql -h "${ALL_ENDPOINTS[0]}" -u admin -p"$DB_PASSWORD" --ssl-mode=REQUIRED 2>/dev/null <<EOF
SELECT MEMBER_HOST, MEMBER_PORT, MEMBER_STATE, MEMBER_ROLE 
FROM performance_schema.replication_group_members 
ORDER BY MEMBER_STATE, MEMBER_HOST;
EOF
    exit 1
fi
echo ""

# Test 2: Write to Region 1, Read from Region 2
echo "Test 2: Cross-Region Replication (Region 1 → Region 2)"
echo "-----------------------------"
log_info "Writing to ${REGION1_ENDPOINTS[0]} (Region 1)..."

RANDOM_VALUE=$RANDOM
mysql -h "${REGION1_ENDPOINTS[0]}" -u admin -p"$DB_PASSWORD" --ssl-mode=REQUIRED 2>/dev/null <<EOF
CREATE DATABASE IF NOT EXISTS test_replication;
USE test_replication;
CREATE TABLE IF NOT EXISTS test_table (
    id INT AUTO_INCREMENT PRIMARY KEY,
    instance VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
INSERT INTO test_table (instance) VALUES ('test-r1-${RANDOM_VALUE}');
EOF

sleep 3

log_info "Reading from ${REGION2_ENDPOINTS[$LAST_R2_IDX]} (Region 2)..."
READ_VALUE=$(mysql -h "${REGION2_ENDPOINTS[$LAST_R2_IDX]}" -u admin -p"$DB_PASSWORD" --ssl-mode=REQUIRED -N 2>/dev/null <<EOF
USE test_replication;
SELECT instance FROM test_table WHERE instance='test-r1-${RANDOM_VALUE}';
EOF
)

if [ "$READ_VALUE" == "test-r1-${RANDOM_VALUE}" ]; then
    log_success "Data replicated from Region 1 to Region 2"
else
    log_error "Data NOT replicated across regions"
    log_info "Expected: test-r1-${RANDOM_VALUE}, Got: ${READ_VALUE}"
    exit 1
fi
echo ""

# Test 3: Write to Region 2, Read from Region 1
echo "Test 3: Cross-Region Replication (Region 2 → Region 1)"
echo "-----------------------------"
log_info "Writing to ${REGION2_ENDPOINTS[0]} (Region 2)..."

RANDOM_VALUE2=$RANDOM
mysql -h "${REGION2_ENDPOINTS[0]}" -u admin -p"$DB_PASSWORD" --ssl-mode=REQUIRED 2>/dev/null <<EOF
USE test_replication;
INSERT INTO test_table (instance) VALUES ('test-r2-${RANDOM_VALUE2}');
EOF

sleep 3

log_info "Reading from ${REGION1_ENDPOINTS[$LAST_R1_IDX]} (Region 1)..."
READ_VALUE2=$(mysql -h "${REGION1_ENDPOINTS[$LAST_R1_IDX]}" -u admin -p"$DB_PASSWORD" --ssl-mode=REQUIRED -N 2>/dev/null <<EOF
USE test_replication;
SELECT instance FROM test_table WHERE instance='test-r2-${RANDOM_VALUE2}';
EOF
)

if [ "$READ_VALUE2" == "test-r2-${RANDOM_VALUE2}" ]; then
    log_success "Data replicated from Region 2 to Region 1"
else
    log_error "Data NOT replicated across regions"
    log_info "Expected: test-r2-${RANDOM_VALUE2}, Got: ${READ_VALUE2}"
    exit 1
fi
echo ""

# Test 4: Concurrent writes from all instances
echo "Test 4: Concurrent Multi-Primary Writes"
echo "-----------------------------"
log_info "Writing concurrently from all $TOTAL_COUNT instances..."

TIMESTAMP=$(date +%s)

# Write from all instances in parallel
for i in "${!ALL_ENDPOINTS[@]}"; do
    (
        mysql -h "${ALL_ENDPOINTS[$i]}" -u admin -p"$DB_PASSWORD" --ssl-mode=REQUIRED 2>/dev/null <<EOF
USE test_replication;
INSERT INTO test_table (instance) VALUES ('concurrent-instance-$i-${TIMESTAMP}');
EOF
    ) &
done

# Wait for all writes to complete
wait

sleep 3

log_info "Verifying all writes replicated..."
CONCURRENT_COUNT=$(mysql -h "${ALL_ENDPOINTS[0]}" -u admin -p"$DB_PASSWORD" --ssl-mode=REQUIRED -N 2>/dev/null <<EOF
USE test_replication;
SELECT COUNT(*) FROM test_table WHERE instance LIKE 'concurrent-instance-%-${TIMESTAMP}';
EOF
)

if [ "$CONCURRENT_COUNT" -eq "$TOTAL_COUNT" ]; then
    log_success "All $TOTAL_COUNT concurrent writes replicated successfully"
else
    log_error "Only $CONCURRENT_COUNT/$TOTAL_COUNT concurrent writes found"
    exit 1
fi
echo ""

# Test 5: Check replication status and performance
echo "Test 5: Replication Status & Performance"
echo "-----------------------------"
log_info "Checking replication lag and conflicts..."

mysql -h "${ALL_ENDPOINTS[0]}" -u admin -p"$DB_PASSWORD" --ssl-mode=REQUIRED 2>/dev/null <<EOF || log_info "Stats query completed"
SELECT 
    MEMBER_HOST,
    COUNT_TRANSACTIONS_IN_QUEUE as 'Queue',
    COUNT_TRANSACTIONS_CHECKED as 'Checked',
    COUNT_CONFLICTS_DETECTED as 'Conflicts'
FROM performance_schema.replication_group_member_stats
ORDER BY MEMBER_HOST;
EOF

echo ""

# Test 6: Show detailed cluster status
echo "Test 6: Detailed Cluster Status"
echo "-----------------------------"
log_info "Current cluster configuration..."

mysql -h "${ALL_ENDPOINTS[0]}" -u admin -p"$DB_PASSWORD" --ssl-mode=REQUIRED 2>/dev/null <<EOF
SELECT 
    MEMBER_HOST,
    MEMBER_PORT,
    MEMBER_STATE,
    MEMBER_ROLE,
    MEMBER_VERSION
FROM performance_schema.replication_group_members
ORDER BY MEMBER_HOST;
EOF

echo ""

# Test 7: Row count verification
echo "Test 7: Data Consistency Check"
echo "-----------------------------"
log_info "Verifying row counts across all instances..."

ALL_MATCH=true
EXPECTED_COUNT=""

for i in "${!ALL_ENDPOINTS[@]}"; do
    ROW_COUNT=$(mysql -h "${ALL_ENDPOINTS[$i]}" -u admin -p"$DB_PASSWORD" --ssl-mode=REQUIRED -N 2>/dev/null <<EOF
USE test_replication;
SELECT COUNT(*) FROM test_table;
EOF
    )
    
    if [ -z "$EXPECTED_COUNT" ]; then
        EXPECTED_COUNT=$ROW_COUNT
    fi
    
    if [ "$ROW_COUNT" -eq "$EXPECTED_COUNT" ]; then
        log_success "Instance $((i+1)): $ROW_COUNT rows (matches)"
    else
        log_error "Instance $((i+1)): $ROW_COUNT rows (expected $EXPECTED_COUNT)"
        ALL_MATCH=false
    fi
done

if [ "$ALL_MATCH" = true ]; then
    log_success "All instances have consistent data ($EXPECTED_COUNT rows)"
else
    log_error "Data inconsistency detected across instances"
    exit 1
fi
echo ""

# Summary
echo "========================================="
echo "Test Results Summary"
echo "========================================="
log_success "✓ Cluster membership verified ($TOTAL_COUNT instances ONLINE)"
log_success "✓ Region 1 → Region 2 replication working"
log_success "✓ Region 2 → Region 1 replication working"
log_success "✓ Concurrent multi-primary writes successful"
log_success "✓ Data consistency verified across all instances"
echo ""
echo -e "${GREEN}All tests passed! Your Multi-AZ Active-Active cluster is fully operational.${NC}"
echo ""
echo "Connection commands:"
for i in "${!ALL_ENDPOINTS[@]}"; do
    if [ "$i" -lt "${#REGION1_ENDPOINTS[@]}" ]; then
        echo "  Region 1 Instance $((i+1)): mysql -h ${ALL_ENDPOINTS[$i]} -u admin -p --ssl-mode=REQUIRED"
    else
        idx=$((i - ${#REGION1_ENDPOINTS[@]}))
        echo "  Region 2 Instance $((idx+1)): mysql -h ${ALL_ENDPOINTS[$i]} -u admin -p --ssl-mode=REQUIRED"
    fi
done
echo ""
