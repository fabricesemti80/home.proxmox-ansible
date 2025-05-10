#!/bin/bash

set -euo pipefail

echo "Running lsblk..."
lsblk

echo -e "\nFinding Ceph volumes..."

# Get list of LVs with 'ceph' in the name
CEPH_LVS=$(lvs --noheadings -o lv_name,vg_name | grep ceph || true)

if [[ -z "$CEPH_LVS" ]]; then
    echo "No Ceph-related logical volumes found."
    exit 0
fi

# Loop through found volumes
echo "$CEPH_LVS" | while read -r LV VG; do
    echo "Removing logical volume: $LV in volume group: $VG"
    lvremove -y "/dev/$VG/$LV"
done

# Get list of Ceph VGs
CEPH_VGS=$(vgs --noheadings -o vg_name | grep ceph || true)
for VG in $CEPH_VGS; do
    echo "Removing volume group: $VG"
    vgremove -y "$VG"
done

# Get list of physical volumes used by Ceph
CEPH_PVS=$(pvs --noheadings -o pv_name,vg_name | grep ceph | awk '{print $1}' || true)
for PV in $CEPH_PVS; do
    echo "Removing physical volume: $PV"
    pvremove -y "$PV"
done

# Find the parent disk(s) used by Ceph (e.g., /dev/sda)
for PV in $CEPH_PVS; do
    DISK=$(lsblk -no pkname "$PV" | head -n1)
    if [[ -n "$DISK" ]]; then
        DEVICE="/dev/$DISK"
        echo "Wiping partition table on $DEVICE with sgdisk --zap-all"
        sgdisk --zap-all "$DEVICE"
    fi
done

echo "Ceph volume cleanup completed."
