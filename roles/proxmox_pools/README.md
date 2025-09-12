# Proxmox Pools Role

This role creates and manages Proxmox VE resource pools using the Proxmox API.

## Requirements

- Proxmox VE cluster with API access
- Valid API token with appropriate permissions
- Python `requests` library on the Ansible control node

## Role Variables

### Required Variables

```yaml
pve_api_user: "terraform@pve"           # API user
pve_api_token_id: "automation"          # API token ID
pve_api_token_secret: "your-secret"     # API token secret
pve_group: "pve01"                      # Proxmox group name
```

### Pool Configuration

```yaml
pve_pools:
  - name: "production"
    comment: "Production VMs and critical services"
    vms: [100, 101, 102]                # VM IDs to add to pool
    storage: ["local-lvm", "ceph1"]     # Storage to add to pool
  - name: "development"
    comment: "Development environment"
    vms: [200, 201]
    storage: ["local-lvm"]
```

## Example Playbook

```yaml
- hosts: pve01
  become: True
  roles:
    - proxmox_pools
```

## Usage

1. Define your pools in `group_vars/pve01` or similar
2. Ensure API credentials are properly configured
3. Run the playbook with the pools tag: `ansible-playbook site.yml --tags pools`

## API Permissions

The API user needs the following permissions:
- Pool.Allocate on /
- VM.Allocate on /
- Datastore.Allocate on /storage

## Notes

- Pools are created on the first node in the cluster only
- VMs and storage are added to pools after creation
- The role handles existing pools gracefully (won't fail if pool already exists)