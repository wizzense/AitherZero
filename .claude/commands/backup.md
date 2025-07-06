# /backup

Backup and restore operations for AitherZero - protect data, configurations, and infrastructure state.

## Usage
```
/backup [action] [options]
```

## Actions

### `create` - Create backup (default)
Create comprehensive backups of specified resources with versioning and compression.

**Options:**
- `--type [full|incremental|differential]` - Backup type (default: incremental)
- `--target [all|config|data|state|logs]` - Backup target (default: all)
- `--name "backup-name"` - Custom backup identifier
- `--compress` - Enable compression (default: true)
- `--encrypt` - Enable encryption
- `--storage [local|azure|aws|s3]` - Storage backend
- `--retention [days]` - Retention period

**Examples:**
```bash
/backup create --type full --encrypt
/backup create --target config --name pre-deployment
/backup create --type incremental --storage azure --retention 30
```

### `restore` - Restore from backup
Restore data from backup with validation and selective restoration options.

**Options:**
- `--name "backup-name"` - Backup identifier to restore
- `--date "YYYY-MM-DD"` - Restore from specific date
- `--target [all|config|data|state|logs]` - Restore target
- `--preview` - Preview restore without applying
- `--validate` - Validate backup integrity
- `--force` - Force restore without confirmation

**Examples:**
```bash
/backup restore --name pre-deployment --preview
/backup restore --date 2025-01-15 --target config
/backup restore --name emergency --validate --force
```

### `list` - List available backups
Display available backups with metadata and storage information.

**Options:**
- `--storage [all|local|remote]` - Storage location filter
- `--age [days]` - Show backups newer than X days
- `--type [full|incremental|differential]` - Filter by backup type
- `--size` - Include size information
- `--verify` - Verify backup integrity

**Examples:**
```bash
/backup list
/backup list --storage remote --age 7
/backup list --type full --size --verify
```

### `schedule` - Manage backup schedules
Configure automated backup schedules with retention policies.

**Options:**
- `--action [create|update|delete|list]` - Schedule operation
- `--name "schedule-name"` - Schedule identifier
- `--cron "cron-expression"` - Schedule timing
- `--type [full|incremental]` - Backup type for schedule
- `--retention [days]` - Automatic cleanup after X days

**Examples:**
```bash
/backup schedule --action create --name daily --cron "0 2 * * *" --type incremental
/backup schedule --action update --name weekly --retention 90
/backup schedule --action list
```

### `verify` - Verify backup integrity
Check backup integrity and validate restoration capability.

**Options:**
- `--name "backup-name"` - Specific backup to verify
- `--all` - Verify all backups
- `--deep` - Perform deep verification
- `--fix` - Attempt to fix corrupted backups
- `--report` - Generate verification report

**Examples:**
```bash
/backup verify --name critical-backup --deep
/backup verify --all --report
/backup verify --name production-2025-01 --fix
```

### `cleanup` - Cleanup old backups
Remove old backups based on retention policies and storage constraints.

**Options:**
- `--older-than [days]` - Remove backups older than X days
- `--keep-min [count]` - Minimum backups to retain
- `--type [full|incremental|differential]` - Target backup type
- `--dry-run` - Preview cleanup without deletion
- `--force` - Skip confirmation prompts

**Examples:**
```bash
/backup cleanup --older-than 90 --keep-min 3 --dry-run
/backup cleanup --type incremental --older-than 30
/backup cleanup --force
```

### `export` - Export backup
Export backup to external storage or different format.

**Options:**
- `--name "backup-name"` - Backup to export
- `--format [tar|zip|7z]` - Export format
- `--destination "path"` - Export destination
- `--split [size]` - Split into chunks (e.g., "1GB")
- `--checksum` - Generate checksums

**Examples:**
```bash
/backup export --name production-full --format zip --destination /mnt/external
/backup export --name critical --split 4GB --checksum
```

### `snapshot` - Infrastructure snapshots
Create point-in-time snapshots of infrastructure state.

**Options:**
- `--resource [vm|database|storage|all]` - Resource type
- `--name "snapshot-name"` - Snapshot identifier
- `--consistent` - Ensure application consistency
- `--tags "key=value"` - Tag snapshots
- `--expire [hours]` - Auto-expiration time

**Examples:**
```bash
/backup snapshot --resource vm --name pre-update --consistent
/backup snapshot --resource database --tags "purpose=compliance"
/backup snapshot --resource all --expire 24
```

## Backup Strategies

### Backup Types
- **Full Backup** - Complete backup of all data
- **Incremental Backup** - Changes since last backup
- **Differential Backup** - Changes since last full backup
- **Snapshot Backup** - Point-in-time infrastructure state

### 3-2-1 Rule Implementation
- **3 copies** of important data
- **2 different** storage media types
- **1 offsite** backup copy

### Retention Policies
```yaml
retention:
  daily:
    count: 7
    type: incremental
  weekly:
    count: 4
    type: differential
  monthly:
    count: 12
    type: full
  yearly:
    count: 7
    type: full
```

## Advanced Features

### Intelligent Backup
- **Change detection** - Backup only modified data
- **Deduplication** - Eliminate duplicate data
- **Compression** - Reduce storage requirements
- **Parallelization** - Multi-threaded backup operations

### Disaster Recovery
- **RTO optimization** - Minimize recovery time
- **RPO management** - Control data loss tolerance
- **Automated failover** - Quick disaster recovery
- **DR testing** - Regular recovery drills

### Backup Validation
- **Integrity checks** - Verify backup consistency
- **Recovery testing** - Automated restore tests
- **Corruption detection** - Early problem identification
- **Health monitoring** - Continuous backup health

### Security Features
- **Encryption at rest** - AES-256 encryption
- **Encryption in transit** - TLS 1.3 protection
- **Access control** - Role-based permissions
- **Audit logging** - Complete operation tracking

## Storage Backends

### Local Storage
```powershell
# Local backup configuration
/backup create --storage local --path "D:/Backups/AitherZero"
```

### Azure Storage
```powershell
# Azure blob storage backup
/backup create --storage azure --container "aither-backups" --encrypt
```

### AWS S3
```powershell
# S3 backup with lifecycle policies
/backup create --storage s3 --bucket "company-backups" --region "us-east-1"
```

### Network Storage
```powershell
# SMB/NFS network backup
/backup create --storage network --path "\\\\nas\\backups\\aitherzero"
```

## Integration Points

### BackupManager Module
- **Consolidation** - Merge multiple backups
- **Optimization** - Storage efficiency
- **Reporting** - Backup analytics
- **Automation** - Scheduled operations

### Infrastructure Integration
- **Pre-backup hooks** - Application quiescing
- **Post-backup hooks** - Notification and validation
- **VSS integration** - Windows Volume Shadow Copy
- **Database hooks** - Consistent DB backups

### Monitoring Integration
- **Backup metrics** - Success rates and performance
- **Alert integration** - Failure notifications
- **Dashboard widgets** - Backup status visualization
- **SLA tracking** - Backup compliance monitoring

## Best Practices

1. **Regular testing** - Verify restore procedures monthly
2. **Multiple locations** - Use geographic redundancy
3. **Encryption always** - Protect sensitive data
4. **Document procedures** - Maintain recovery runbooks
5. **Monitor continuously** - Track backup health
6. **Automate scheduling** - Reduce human error
7. **Version retention** - Keep multiple versions
8. **Compliance alignment** - Meet regulatory requirements

## Recovery Procedures

### Quick Recovery
```bash
# List recent backups
/backup list --age 7

# Preview restore
/backup restore --name latest --preview

# Perform restore
/backup restore --name latest --target config
```

### Disaster Recovery
```bash
# Full system recovery
/backup restore --name dr-backup --type full --validate

# Staged recovery
/backup restore --name dr-backup --target config
/backup restore --name dr-backup --target data
/backup restore --name dr-backup --target state
```

### Selective Recovery
```bash
# Restore specific modules
/backup restore --name production --target config --filter "modules/LabRunner"

# Point-in-time recovery
/backup restore --date 2025-01-15 --time "14:30:00"
```

## Monitoring and Reporting

### Backup Dashboard
- **Success rate** - Backup completion percentage
- **Storage usage** - Capacity and growth trends
- **Recovery tests** - Validation results
- **Performance metrics** - Backup/restore speeds

### Compliance Reports
- **Backup coverage** - Protected vs unprotected resources
- **Retention compliance** - Policy adherence
- **Recovery capability** - RTO/RPO achievement
- **Audit trail** - Complete operation history

## Troubleshooting

### Common Issues
- **Backup failures** - Check permissions and storage space
- **Slow performance** - Optimize compression and deduplication
- **Restore errors** - Verify backup integrity first
- **Storage issues** - Monitor capacity and connectivity

### Debug Commands
```bash
# Verbose backup with diagnostics
/backup create --type full --verbose --debug

# Test storage connectivity
/backup test --storage azure --debug

# Analyze backup performance
/backup analyze --name slow-backup --performance
```

The `/backup` command provides enterprise-grade data protection with automated operations and comprehensive disaster recovery capabilities.