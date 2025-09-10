# Proxmox Backup Role

This Ansible role configures automated backup jobs for Proxmox VE VMs and templates using the Proxmox backup scheduler.

## Features

- **VM Backup Jobs** - Automated backups of running VMs
- **Template Backup Jobs** - Automated backups of VM templates
- **Flexible Scheduling** - Configurable backup schedules
- **Retention Policies** - Automatic cleanup of old backups
- **Email Notifications** - Optional email alerts on backup completion/failure
- **Performance Tuning** - Configurable I/O priority and bandwidth limits

## Requirements

- Proxmox VE cluster with backup storage configured
- NFS storage `nfs-proxmox-backup` must exist and be accessible
- Optional: API token for API-based configuration (falls back to CLI)

## Variables

### Backup Storage
```yaml
backup_storage: "nfs-proxmox-backup"  # Storage ID for backups
```

### VM Backup Configuration
```yaml
vm_backup:
  name: "vm-backup"           # Backup job name
  schedule: "01:00"           # Time in 24-hour format (HH:MM)
  dow: "sun"                  # Day of week (sun, mon, tue, wed, thu, fri, sat)
  vm_ids: [1020, 1021]        # List of VM IDs to backup
  enabled: true               # Enable/disable backup job
  compress: "zstd"            # Compression: none, lzo, gzip, zstd
  mode: "snapshot"            # Backup mode: snapshot, suspend, stop
  retention:
    keep_daily: 7             # Keep daily backups for 7 days
    keep_weekly: 4            # Keep weekly backups for 4 weeks
    keep_monthly: 3           # Keep monthly backups for 3 months
  notification: true          # Send notifications
  email_on_failure: true      # Send email only on failure
```

### Template Backup Configuration
```yaml
template_backup:
  name: "template-backup"     # Backup job name
  schedule: "02:00"           # Time in 24-hour format (HH:MM)
  dow: "sun"                  # Day of week (after VM backup)
  vm_ids: [6006]              # List of template IDs to backup
  enabled: true               # Enable/disable backup job
  # ... same options as vm_backup
```

### Global Settings
```yaml
backup_global:
  max_workers: 1              # Parallel backup jobs
  bandwidth_limit: 0          # Bandwidth limit KB/s (0=unlimited)
  ionice: 7                   # I/O priority (0-7, 7=lowest)
  lockwait: 180               # VM lock wait time (minutes)
```

### Optional Email Configuration
```yaml
backup_notification_email: "admin@example.com"  # Email for notifications
```

## Schedule Format

The schedule uses separate time and day-of-week parameters:
- `schedule: "01:00"` + `dow: "sun"` - Sunday at 1:00 AM
- `schedule: "23:30"` + `dow: "mon"` - Monday at 11:30 PM
- `schedule: "02:00"` + `dow: "fri"` - Friday at 2:00 AM

Day of week options: `sun`, `mon`, `tue`, `wed`, `thu`, `fri`, `sat`

## Backup Modes

- **snapshot** - Create VM snapshot, backup, remove snapshot (recommended)
- **suspend** - Suspend VM, backup, resume VM
- **stop** - Stop VM, backup, start VM

## Compression Options

- **none** - No compression (fastest)
- **lzo** - Fast compression
- **gzip** - Good compression ratio
- **zstd** - Best compression ratio (recommended)

## Usage Example

```yaml
# In group_vars/pve01
vm_backup:
  vm_ids: [100, 101, 102]     # Your VM IDs
  schedule: "23:00"           # 11 PM
  dow: "sat"                  # Saturday

template_backup:
  vm_ids: [9000, 9001]        # Your template IDs
  schedule: "01:00"           # 1 AM
  dow: "sun"                  # Sunday

backup_notification_email: "{{ gmail_smtp_username }}"
```

## What This Role Does

1. Verifies backup storage exists and is accessible
2. Creates VM backup job with specified VMs and schedule
3. Creates template backup job with specified templates and schedule
4. Configures retention policies for automatic cleanup
5. Sets up email notifications (if configured)
6. Applies performance and I/O settings

## Integration with Gmail SMTP

If you've configured Gmail SMTP, set:
```yaml
backup_notification_email: "{{ gmail_smtp_username }}"
```

This will send backup notifications to your Gmail address.

## Monitoring Backups

After configuration, monitor backups via:
- **Proxmox Web UI:** Datacenter → Backup
- **CLI:** `pvesh get /cluster/backup`
- **Logs:** `/var/log/vzdump.log`

## Troubleshooting

### Common Issues

1. **Storage not found:**
   - Verify `nfs-proxmox-backup` storage exists in Proxmox
   - Check NFS server connectivity

2. **VM/Template not found:**
   - Verify VM/template IDs exist: `qm list`
   - Check VM/template is not locked

3. **Permission issues:**
   - Ensure API token has backup permissions
   - Check storage permissions for backup user

### Manual Backup Test

Test backup manually:
```bash
# Test VM backup
vzdump 1020 --storage nfs-proxmox-backup --compress zstd

# List backup jobs
pvesh get /cluster/backup

# Check backup logs
tail -f /var/log/vzdump.log
```