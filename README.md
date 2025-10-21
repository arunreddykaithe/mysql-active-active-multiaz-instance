# MySQL Multi-AZ Active-Active Replication

Production-ready MySQL database cluster with active-active replication across AWS regions using Multi-AZ RDS instances and MySQL Group Replication.

## 🏗️ Architecture

### What is Multi-AZ DB Instance?

Each **Multi-AZ DB Instance** deployment automatically includes:
- **1 Primary instance** (read-write, active in Group Replication)
- **1 Standby replica** (automatic synchronous replication for HA)
- **Automatic failover** (sub-60 second) if primary fails
- **Single endpoint** (DNS automatically updates on failover)

### Example Configuration (2 instances per region)

```
┌─────────────────────────────────────────────────────────────────┐
│                  Active-Active Multi-Region Setup               │
└─────────────────────────────────────────────────────────────────┘

Region 1: us-east-2                 Region 2: us-west-2
VPC: 10.10.0.0/24                   VPC: 10.11.0.0/24

Multi-AZ Instance 1                 Multi-AZ Instance 1
┌──────────────────┐                ┌──────────────────┐
│ Primary (AZ-2a)  │◄───────────────┤ Primary (AZ-2a)  │
│ └─ Write/Read    │   Group Repl   │ └─ Write/Read    │
│ Standby (AZ-2b)  │                │ Standby (AZ-2b)  │
│ └─ Auto Failover │                │ └─ Auto Failover │
└──────────────────┘                └──────────────────┘
        ▲                                    ▲
        │                                    │
        ├───────────Group Replication────────┤
        │                                    │
        ▼                                    ▼
Multi-AZ Instance 2                 Multi-AZ Instance 2
┌──────────────────┐                ┌──────────────────┐
│ Primary (AZ-2b)  │◄───────────────┤ Primary (AZ-2b)  │
│ └─ Write/Read    │   Group Repl   │ └─ Write/Read    │
│ Standby (AZ-2c)  │                │ Standby (AZ-2c)  │
│ └─ Auto Failover │                │ └─ Auto Failover │
└──────────────────┘                └──────────────────┘

All 4 PRIMARY instances participate in Group Replication
Standby replicas handle AZ-level failures automatically
```

## ✨ Features

### Flexibility
✅ **Variable instance count** - Deploy 1, 2, or 3 instances per region
✅ **Simple scaling** - Change one variable to add/remove instances
✅ **Modular Terraform** - Clean, reusable module structure

### High Availability
✅ **Multi-AZ** - Each instance has automatic standby in different AZ
✅ **Active-Active** - All primary instances accept writes
✅ **Dual-layer failover**:
  - AZ failure → Multi-AZ automatic failover
  - Instance failure → Group Replication handles it

### Production Ready
✅ **Same VPC structure** - As your existing setup
✅ **Public access** - Configurable (can be disabled)
✅ **Active-active scripts** - Automated setup and testing
✅ **Cleanup scripts** - Safe resource deletion

## 📊 Deployment Options

### Option 1: Minimal (1+1 configuration)
```hcl
region1_instance_count = 1
region2_instance_count = 1
```
- 2 primary instances + 2 standbys
- Cost: ~$260/month (db.t3.medium)
- Good for: Development, testing

### Option 2: Balanced (2+2 configuration) **← Recommended**
```hcl
region1_instance_count = 2
region2_instance_count = 2
```
- 4 primary instances + 4 standbys
- Cost: ~$500/month (db.t3.medium)
- Good for: Production with good HA

### Option 3: Maximum (3+3 configuration)
```hcl
region1_instance_count = 3
region2_instance_count = 3
```
- 6 primary instances + 6 standbys
- Cost: ~$740/month (db.t3.medium)
- Good for: High-traffic production

## 🚀 Quick Start

### Prerequisites

- AWS CLI configured
- Terraform >= 1.0
- MySQL client
- `jq` installed

### 1. Clone and Configure

```bash
git clone <repo>
cd mysql-multiaz-active-active

# Customize configuration
cp terraform.tfvars.example terraform.tfvars
vim terraform.tfvars
```

**Key settings:**

```hcl
# How many instances per region? (1, 2, or 3)
region1_instance_count = 2
region2_instance_count = 2

# Security (CHANGE THESE!)
db_password = "YourSecurePassword123!"
allowed_cidr_blocks = ["YOUR.IP/32"]  # Restrict access!
```

### 2. Deploy Infrastructure

```bash
# Initialize
terraform init

# Review what will be created
terraform plan

# Deploy (takes ~20 minutes)
terraform apply
```

**What gets created:**
- 2 VPCs with subnets across 3 AZs each
- VPC peering between regions
- X Multi-AZ RDS instances per region (based on your count)
- Parameter groups with Group Replication settings
- Security groups

### 3. Setup Group Replication

```bash
# Make scripts executable
chmod +x scripts/*.sh

# Run setup (takes ~5 minutes)
./scripts/setup_replication.sh

# You'll be prompted for:
# - Database password
# - Group Replication user password
```

**The script will:**
1. Detect all instances automatically
2. Configure Group Replication seeds
3. Bootstrap the cluster
4. Join all instances to the group
5. Verify cluster status
6. Test replication

### 4. Verify

```bash
# Run tests
./scripts/test_replication.sh

# Tests performed:
# ✓ Cluster membership (all instances ONLINE)
# ✓ Region 1 → Region 2 replication
# ✓ Region 2 → Region 1 replication
# ✓ Replication lag check
# ✓ Multi-AZ status verification
```

## 📝 Usage

### Connect to Database

```bash
# Get connection commands
terraform output connection_summary

# Example (Region 1, Instance 1):
mysql -h mysql-multiaz-us-east-2-1.xxx.rds.amazonaws.com -u admin -p
```

### Check Cluster Status

```sql
SELECT 
    MEMBER_HOST,
    MEMBER_STATE,
    MEMBER_ROLE
FROM performance_schema.replication_group_members;
```

Expected output: All instances show `MEMBER_STATE='ONLINE'`

### Scale Up/Down

```hcl
# Edit terraform.tfvars
region1_instance_count = 3  # Was 2, now 3

# Apply changes
terraform apply

# Re-run setup to add new instance to cluster
./scripts/setup_replication.sh
```

## 💰 Cost Estimates

### With db.t3.medium (2 vCPU, 4GB RAM)

| Configuration | Monthly Cost |
|---------------|-------------|
| 1+1 (minimal) | ~$260 |
| 2+2 (recommended) | ~$500 |
| 3+3 (maximum) | ~$740 |

**Cost breakdown (2+2 example):**
- 4x db.t3.medium Multi-AZ @ ~$120/mo each = $480
- VPC Peering + Data Transfer = ~$20
- **Total: ~$500/month**

### Cost Optimization

**To reduce costs:**
- Use db.t3.small (~$60/mo per Multi-AZ) → ~$260/mo for 2+2
- Use 1+1 configuration → ~$130/mo with db.t3.small

**To increase performance:**
- Use db.r5.large (~$350/mo per Multi-AZ) → ~$1,400/mo for 2+2
- Use 3+3 configuration for higher capacity

## 🔧 Customization

### Change Instance Class

```hcl
# terraform.tfvars
db_instance_class = "db.r5.large"  # More powerful
# OR
db_instance_class = "db.t3.small"  # More economical
```

### Change Regions

```hcl
region1 = "us-west-1"   # Change from us-east-2
region2 = "eu-west-1"   # Change from us-west-2

# Also update VPC CIDRs to avoid conflicts
region1_vpc_cidr = "10.20.0.0/24"
region2_vpc_cidr = "10.21.0.0/24"
```

### Disable Public Access (Production)

```hcl
db_publicly_accessible = false
allowed_cidr_blocks = ["10.0.0.0/8"]  # VPN/Internal only
```

## 🛠️ Maintenance

### Backup and Recovery

**Automated Backups:**
- Enabled by default (required for Group Replication)
- Retention: 7 days (configurable)
- Point-in-time recovery available

**Manual Snapshot:**

```bash
aws rds create-db-snapshot \
  --db-instance-identifier mysql-multiaz-us-east-2-1 \
  --db-snapshot-identifier manual-$(date +%Y%m%d)
```

### Failover Testing

**Multi-AZ Failover:**

```bash
# Force failover of specific instance
aws rds reboot-db-instance \
  --db-instance-identifier mysql-multiaz-us-east-2-1 \
  --force-failover
```

Standby becomes primary in ~30-60 seconds. Endpoint stays the same.

**Group Replication Failover:**

If an entire instance fails, Group Replication automatically removes it from the cluster. Remaining instances continue serving traffic.

## 🗑️ Cleanup

```bash
# Run cleanup script
./scripts/cleanup.sh

# You'll be prompted:
# 1. Confirm deletion (type 'yes')
# 2. Confirm again (type 'DELETE')
# 3. Whether to create final snapshots
```

## 📁 Project Structure

```
mysql-multiaz-active-active/
├── README.md
├── providers.tf              # AWS provider config
├── variables.tf              # Input variables
├── outputs.tf                # Dynamic outputs
├── data.tf                   # Data sources & locals
├── terraform.tfvars          # Your configuration
├── region1.tf                # Region 1 (dynamic count)
├── region2.tf                # Region 2 (dynamic count)
├── peering.tf                # VPC peering
│
├── modules/
│   ├── vpc/                  # VPC module (reused from previous)
│   ├── rds-multiaz/          # Multi-AZ RDS module
│   └── peering/              # Peering module (reused from previous)
│
└── scripts/
    ├── setup_replication.sh  # Setup Group Replication
    ├── test_replication.sh   # Test replication
    └── cleanup.sh            # Safe cleanup
```

## 🐛 Troubleshooting

### Instance Not Joining Cluster

```sql
-- Check Group Replication status
SHOW VARIABLES LIKE 'group_replication%';

-- Check for errors
SELECT * FROM performance_schema.replication_group_members;
```

### Replication Lag

```sql
-- Check transaction queue
SELECT 
    MEMBER_HOST,
    COUNT_TRANSACTIONS_IN_QUEUE 
FROM performance_schema.replication_group_member_stats
WHERE COUNT_TRANSACTIONS_IN_QUEUE > 100;
```

**Solution:** Check network latency, review slow queries, consider upgrading instance class.

## ⚠️ Important Notes

- **Multi-AZ standbys** are NOT part of Group Replication cluster
- Each region can have 1-3 **primary** instances in the cluster
- Standby replicas only activate on AZ failure (automatic)
- Maximum 9 instances total in Group Replication (AWS limit)
- With 3+3 configuration, you have 6 instances (within limit)

## 📚 Resources

- [AWS Multi-AZ Documentation](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Concepts.MultiAZ.html)
- [MySQL Group Replication](https://dev.mysql.com/doc/refman/8.0/en/group-replication.html)
- [RDS Group Replication on AWS](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/mysql-active-active-clusters.html)

---
Arun Kaithe
**Built for flexibility and production use** 🚀
