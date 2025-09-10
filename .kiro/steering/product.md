# Product Overview

This is an Ansible-based infrastructure automation project for deploying and managing a Proxmox Virtual Environment (PVE) cluster. The project automates the complete setup of a 3-node Proxmox cluster with Ceph storage, networking configuration, and NFS storage integration.

## Key Features

- Automated Proxmox VE cluster deployment
- Ceph distributed storage configuration
- Network interface management with bridge configuration
- NFS storage integration for backups, ISOs, and templates
- User and permission management for API automation tools
- SSH key deployment and security hardening

## Target Environment

- 3-node Proxmox cluster (pve-0, pve-1, pve-2)
- Network segments: 10.0.40.0/24 (management) and 10.0.70.0/24 (Ceph)
- External NFS server at 10.0.40.2 for shared storage
- Debian 12 base OS on each node