# Project Structure

## Root Level Files

- `ansible.cfg`: Ansible configuration with inventory path, fact caching, and SSH settings
- `site.yml`: Main playbook orchestrating the complete Proxmox deployment
- `inventory`: Ansible inventory defining the 3-node cluster hosts and connection details
- `Taskfile.yml`: Task automation definitions for common operations
- `notes.md`: Deployment notes and manual configuration examples

## Directory Organization

### `/group_vars/`
Variable definitions organized by host groups:
- `all`: Global variables (NTP configuration, timezone)
- `pve01`: Proxmox cluster-specific variables (storage, networking, Ceph config)

### `/files/`
Static files for deployment:
- SSH key pairs for automated access (`root_pve_rsa`, `root_pve_rsa.pub`)

### `/templates/`
Jinja2 templates for configuration files:
- `interfaces-pve01.j2`: Network interface configuration template

### `/roles/`
- `requirements.yml`: External Ansible roles dependencies

### `/hack/`
Utility scripts for maintenance:
- `clean_ceph_services.sh`: Ceph service cleanup
- `clean_ceph_volumes.sh`: Ceph volume cleanup

## Configuration Patterns

### Variable Hierarchy
1. `group_vars/all`: Global settings (NTP, timezone)
2. `group_vars/pve01`: Cluster-specific configuration
3. Host-specific variables in inventory file

### Naming Conventions
- Host groups: `pve01` (cluster identifier)
- Hostnames: `pve-{number}.fabricesemti.dev`
- Network interfaces: `vmbr0` (bridge), `enp2s0` (physical)
- Storage naming: `nfs-proxmox-{purpose}`, `ceph1`

### Template Usage
- Network configuration uses group-specific templates
- Template selection via `interfaces_template` variable
- Jinja2 templating for dynamic configuration generation