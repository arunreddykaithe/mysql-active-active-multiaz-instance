#!/bin/bash

# ========================================
# MySQL Multi-AZ Active-Active Cleanup Script
# Safely destroys all resources
# ========================================

set -e

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m'

log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }

echo "========================================="
echo "MySQL Multi-AZ Active-Active Cleanup"
echo "========================================="
echo ""

# Check if Terraform state exists
if [ ! -f "terraform.tfstate" ]; then
    log_error "No terraform.tfstate found. Nothing to clean up."
    exit 0
fi

# Get current deployment info
log_warning "Current deployment:"
terraform output deployment_summary 2>/dev/null || echo "Unable to read deployment info"
echo ""

# Warning
log_warning "⚠️  This will DESTROY all resources including:"
log_warning "  - All RDS instances (Multi-AZ)"
log_warning "  - All VPCs and networking"
log_warning "  - All security groups"
log_warning "  - All parameter groups"
echo ""

# Prompt for confirmation
read -p "Type 'yes' to continue with cleanup: " CONFIRM1

if [ "$CONFIRM1" != "yes" ]; then
    echo "Cleanup cancelled."
    exit 0
fi

echo ""
log_warning "Are you absolutely sure? This action CANNOT be undone!"
read -p "Type 'DELETE' to confirm: " CONFIRM2

if [ "$CONFIRM2" != "DELETE" ]; then
    echo "Cleanup cancelled."
    exit 0
fi

echo ""

# Ask about final snapshots
read -p "Create final snapshots before deletion? (y/n): " SNAPSHOTS

if [ "$SNAPSHOTS" == "y" ]; then
    log_warning "Setting skip_final_snapshot=false in terraform.tfvars..."
    sed -i.bak 's/skip_final_snapshot = true/skip_final_snapshot = false/' terraform.tfvars 2>/dev/null || true
fi

echo ""
echo "Starting cleanup..."
echo ""

# Run terraform destroy
terraform destroy -auto-approve

echo ""

if [ "$SNAPSHOTS" == "y" ]; then
    log_success "Resources destroyed. Final snapshots were created."
    log_warning "Don't forget to manually delete snapshots later if not needed:"
    echo "    aws rds describe-db-snapshots --query 'DBSnapshots[?starts_with(DBSnapshotIdentifier, \`mysql-multiaz\`)].DBSnapshotIdentifier'"
else
    log_success "All resources destroyed successfully!"
fi

echo ""
echo "Cleanup complete."
echo ""
