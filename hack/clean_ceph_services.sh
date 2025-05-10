#!/bin/bash

set -euo pipefail

echo "Stopping Ceph services..."
systemctl stop ceph-mon.target || true
systemctl stop ceph-mgr.target || true
systemctl stop ceph-mds.target || true
systemctl stop ceph-osd.target || true

echo "Removing systemd service files..."
rm -rf /etc/systemd/system/ceph* || true

echo "Killing any remaining Ceph processes..."
killall -9 ceph-mon ceph-mgr ceph-mds || true

echo "Removing Ceph runtime directories..."
rm -rf /var/lib/ceph/mon/ /var/lib/ceph/mgr/ /var/lib/ceph/mds/ || true

echo "Purging Ceph from Proxmox..."
pveceph purge || true

echo "Uninstalling Ceph packages..."
apt purge -y ceph-mon ceph-osd ceph-mgr ceph-mds || true
apt purge -y ceph-base ceph-mgr-modules-core || true

echo "Cleaning up Ceph configuration files..."
rm -rf /etc/ceph/* || true
rm -rf /etc/pve/ceph.conf || true
rm -rf /etc/pve/priv/ceph.* || true

echo "Ceph purge complete."
