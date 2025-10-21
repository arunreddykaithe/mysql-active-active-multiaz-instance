#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[⚠]${NC} $1"; }
log_error() { echo -e "${RED}[✗]${NC} $1"; }

REGION1_ENDPOINTS=($(terraform output -json region1_rds_endpoints | jq -r '.[]'))

read -s -p "Enter database password: " DB_PASSWORD
echo ""
echo ""

while true; do
    clear
    echo "========================================="
    echo "MySQL Multi-AZ Active-Active Health Monitor"
    echo "Updated: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "========================================="
    echo ""
    
    # Check Group Replication Status
    echo "Group Replication Cluster Status:"
    echo "-----------------------------------"
    
    MEMBER_COUNT=$(mysql -h "${REGION1_ENDPOINTS[0]}" -u admin -p"$DB_PASSWORD" --ssl-mode=REQUIRED -N 2>/dev/null <<'EOSQL'
SELECT COUNT(*) FROM performance_schema.replication_group_members WHERE MEMBER_STATE='ONLINE';
EOSQL
)
    
    if [ "$MEMBER_COUNT" -eq 4 ]; then
        log_success "All 4 members ONLINE - Cluster healthy"
    elif [ "$MEMBER_COUNT" -ge 3 ]; then
        log_warning "$MEMBER_COUNT/4 members ONLINE - Quorum maintained but degraded"
    else
        log_error "$MEMBER_COUNT/4 members ONLINE - QUORUM LOST!"
    fi
    
    echo ""
    mysql -h "${REGION1_ENDPOINTS[0]}" -u admin -p"$DB_PASSWORD" --ssl-mode=REQUIRED 2>/dev/null <<'EOSQL'
SELECT 
    SUBSTRING_INDEX(MEMBER_HOST, '.', 1) as Instance,
    MEMBER_STATE as State,
    MEMBER_ROLE as Role,
    IF(MEMBER_STATE='ONLINE', '✓', '✗') as Status
FROM performance_schema.replication_group_members
ORDER BY MEMBER_HOST;
EOSQL
    
    echo ""
    echo "Replication Statistics:"
    echo "-----------------------------------"
    
    mysql -h "${REGION1_ENDPOINTS[0]}" -u admin -p"$DB_PASSWORD" --ssl-mode=REQUIRED 2>/dev/null <<'EOSQL'
SELECT 
    SUBSTRING_INDEX(MEMBER_HOST, '.', 1) as Instance,
    COUNT_TRANSACTIONS_IN_QUEUE as Queue,
    COUNT_CONFLICTS_DETECTED as Conflicts
FROM performance_schema.replication_group_member_stats
ORDER BY MEMBER_HOST;
EOSQL
    
    echo ""
    echo "Press Ctrl+C to exit. Refreshing in 10 seconds..."
    sleep 10
done
