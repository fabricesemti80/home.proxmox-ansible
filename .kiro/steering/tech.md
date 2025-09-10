# Technology Stack

## Core Technologies

- **Ansible**: Infrastructure automation and configuration management
- **Proxmox VE**: Virtualization platform and hypervisor
- **Ceph**: Distributed storage system
- **Debian 12**: Base operating system
- **Task**: Build automation tool (Taskfile.yml)

## Key Dependencies

### Ansible Roles
- `geerlingguy.ntp`: NTP time synchronization
- `lae.proxmox`: Proxmox VE installation and configuration

### System Components
- **bridge-utils**: Network bridge management
- **SSH**: Secure remote access and key-based authentication
- **NFS**: Network file system for shared storage

## Common Commands

### Initial Setup
```bash
# Install Ansible Galaxy requirements
task init
# or
ansible-galaxy install -r roles/requirements.yml --force
```

### Testing and Deployment
```bash
# Dry run with diff to preview changes
task check
# or
ansible-playbook -i inventory site.yml -e '{"pve_reboot_on_kernel_update": true}' --check --diff

# Apply the playbook
task apply
# or
ansible-playbook -i inventory site.yml -e '{"pve_reboot_on_kernel_update": true}'

# List available tasks
task --list
```

### Ansible Configuration
- Uses `ansible.cfg` for default settings
- Inventory file: `./inventory`
- Fact caching enabled with 2-hour timeout
- Host key checking disabled for automation

## Build System

The project uses **Task** (go-task) as the build automation tool with predefined tasks in `Taskfile.yml` for common operations like initialization, testing, and deployment.