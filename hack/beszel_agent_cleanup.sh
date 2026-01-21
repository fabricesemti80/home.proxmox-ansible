#!/bin/bash

# Beszel Agent Complete Removal Script
# This script handles both binary and package installations

set -e

echo "=================================="
echo "Beszel Agent Complete Removal"
echo "=================================="
echo ""

# Function to safely remove files/directories
safe_remove() {
    if [ -e "$1" ]; then
        echo "Removing: $1"
        rm -rf "$1"
    fi
}

# 1. Stop any running processes
echo "[1/10] Stopping Beszel agent processes..."
sudo pkill -9 beszel-agent 2>/dev/null || true
sudo systemctl stop beszel-agent 2>/dev/null || true
sudo systemctl stop beszel-agent-update.service 2>/dev/null || true
sudo systemctl stop beszel-agent-update.timer 2>/dev/null || true

# 2. Disable services
echo "[2/10] Disabling services..."
sudo systemctl disable beszel-agent 2>/dev/null || true
sudo systemctl disable beszel-agent-update.timer 2>/dev/null || true
sudo systemctl disable beszel-agent-update.service 2>/dev/null || true

# 3. Check if installed as package and remove
echo "[3/10] Checking for package installation..."
if dpkg -l | grep -q beszel-agent; then
    echo "Found Debian package, removing..."
    sudo apt purge beszel-agent -y
    sudo apt autoremove -y
else
    echo "Not installed as package, skipping..."
fi

# 4. Remove systemd service files
echo "[4/10] Removing systemd service files..."
safe_remove "/etc/systemd/system/beszel-agent.service"
safe_remove "/etc/systemd/system/beszel-agent-update.service"
safe_remove "/etc/systemd/system/beszel-agent-update.timer"
safe_remove "/etc/systemd/system/beszel-agent.service.d"
safe_remove "/etc/systemd/system/multi-user.target.wants/beszel-agent.service"
safe_remove "/etc/systemd/system/timers.target.wants/beszel-agent-update.timer"
safe_remove "/usr/lib/systemd/system/beszel-agent.service"
safe_remove "/lib/systemd/system/beszel-agent.service"

# 5. Remove systemd helper files
echo "[5/10] Removing systemd helper files..."
safe_remove "/var/lib/systemd/deb-systemd-helper-enabled/multi-user.target.wants/beszel-agent.service"
safe_remove "/var/lib/systemd/deb-systemd-helper-enabled/beszel-agent.service.dsh-also"
safe_remove "/var/lib/systemd/timers/stamp-beszel-agent-update.timer"

# 6. Reload systemd
echo "[6/10] Reloading systemd..."
sudo systemctl daemon-reload
sudo systemctl reset-failed

# 7. Remove binaries
echo "[7/10] Removing binaries..."
safe_remove "/usr/local/bin/beszel-agent"
safe_remove "/usr/bin/beszel-agent"
safe_remove "/opt/beszel/beszel-agent"
safe_remove "/opt/beszel-agent"

# 8. Remove configuration files
echo "[8/10] Removing configuration files..."
safe_remove "/etc/beszel"
safe_remove "/etc/beszel-agent.conf"

# 9. Remove data and log directories
echo "[9/10] Removing data and log directories..."
safe_remove "/var/lib/beszel-agent"
safe_remove "/var/log/beszel-agent"
safe_remove "/opt/beszel"
safe_remove "/home/beszel"

# 10. Remove temporary and package files
echo "[10/10] Removing temporary files..."
safe_remove "/tmp/beszel-agent.tar.gz"
safe_remove "/var/tmp/beszel-agent.deb"
safe_remove "/var/lib/dpkg/info/beszel-agent.prerm"
safe_remove "/var/lib/dpkg/info/beszel-agent.postrm"
safe_remove "/var/lib/dpkg/info/beszel-agent.postinst"
safe_remove "/var/lib/dpkg/info/beszel-agent.md5sums"
safe_remove "/var/lib/dpkg/info/beszel-agent.templates"
safe_remove "/var/lib/dpkg/info/beszel-agent.list"
safe_remove "/usr/share/doc/beszel-agent"
safe_remove "/usr/share/lintian/overrides/beszel-agent"

# 11. Remove Proxmox mount directories
echo "[11/11] Removing Proxmox mount directories..."
safe_remove "/mnt/pve/ceph-proxmox-fs/docker-shared-data/beszel"
safe_remove "/mnt/pve/cephfs-vm/docker-shared-data/beszel"

# Remove user and group if they exist
if id "beszel-agent" &>/dev/null; then
    echo "Removing user: beszel-agent"
    sudo userdel beszel-agent 2>/dev/null || true
fi

if getent group beszel-agent &>/dev/null; then
    echo "Removing group: beszel-agent"
    sudo groupdel beszel-agent 2>/dev/null || true
fi

echo ""
echo "=================================="
echo "Cleanup Complete!"
echo "=================================="
echo ""

# Verification
echo "Verifying cleanup..."
echo ""

# Check for remaining processes
if pgrep -a beszel 2>/dev/null; then
    echo "⚠️  WARNING: Beszel processes still running:"
    pgrep -a beszel
else
    echo "✓ No Beszel processes running"
fi

# Check for remaining packages
if dpkg -l | grep -q beszel; then
    echo "⚠️  WARNING: Beszel packages still installed:"
    dpkg -l | grep beszel
else
    echo "✓ No Beszel packages installed"
fi

# Check for remaining systemd services
if systemctl list-unit-files | grep -q beszel; then
    echo "⚠️  WARNING: Beszel systemd services still exist:"
    systemctl list-unit-files | grep beszel
else
    echo "✓ No Beszel systemd services"
fi

# Check for remaining files
echo ""
echo "Searching for any remaining Beszel files..."
REMAINING=$(sudo find / -name "*beszel*" 2>/dev/null || true)

if [ -n "$REMAINING" ]; then
    echo "⚠️  Found remaining files:"
    echo "$REMAINING"
    echo ""
    echo "You may want to review and manually remove these files."
else
    echo "✓ No remaining Beszel files found"
fi

echo ""