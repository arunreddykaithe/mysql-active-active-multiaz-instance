#!/bin/bash

echo "========================================="
echo "Multi-AZ Configuration Check"
echo "========================================="
echo ""

REGION1_ENDPOINTS=($(terraform output -json region1_rds_endpoints | jq -r '.[]'))
REGION2_ENDPOINTS=($(terraform output -json region2_rds_endpoints | jq -r '.[]'))

check_instance() {
    local instance_id=$1
    local region=$2
    
    echo "Instance: $instance_id"
    aws rds describe-db-instances \
        --db-instance-identifier "$instance_id" \
        --region "$region" \
        --query 'DBInstances[0].{
            MultiAZ:MultiAZ,
            Engine:Engine,
            EngineVersion:EngineVersion,
            PrimaryAZ:AvailabilityZone,
            StandbyAZ:SecondaryAvailabilityZone,
            Endpoint:Endpoint.Address,
            Status:DBInstanceStatus
        }' \
        --output table
    echo ""
}

echo "Region 1 (us-east-2) Instances:"
echo "-------------------------------"
check_instance "mysql-multiaz-activeactive-us-east-2-1" "us-east-2"
check_instance "mysql-multiaz-activeactive-us-east-2-2" "us-east-2"

echo "Region 2 (us-west-2) Instances:"
echo "-------------------------------"
check_instance "mysql-multiaz-activeactive-us-west-2-1" "us-west-2"
check_instance "mysql-multiaz-activeactive-us-west-2-2" "us-west-2"

echo "========================================="
echo "Summary"
echo "========================================="
echo "Multi-AZ provides automatic failover to a standby replica"
echo "within the same region (different AZ)."
echo ""
echo "Your setup has:"
echo "  - Multi-AZ: Standby replicas in different AZs (same region)"
echo "  - Group Replication: Active-Active across all 4 instances"
echo "========================================="
