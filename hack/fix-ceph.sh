#!/bin/bash
set -e

# Configuration
SSH_KEY=~/.ssh/fs_home_rsa
SSH_USER="root"
ALL_NODES=("10.0.40.10" "10.0.40.11" "10.0.40.12")
HEALTHY_NODE="10.0.40.10" # Default node to fetch keys from

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_err() { echo -e "${RED}[ERROR]${NC} $1"; }

check_ssh() {
    local node=$1
    if ! ssh -i $SSH_KEY -o StrictHostKeyChecking=no -o ConnectTimeout=5 $SSH_USER@$node "exit"; then
        log_err "Cannot connect to $node via SSH."
        return 1
    fi
    return 0
}

fix_log_permissions() {
    local node=$1
    log_info "Checking /var/log/ceph permissions on $node..."
    ssh -i $SSH_KEY -o StrictHostKeyChecking=no $SSH_USER@$node "
        if [ -f /var/log/ceph ]; then
            echo 'Found /var/log/ceph as a file. Backing up and replacing with directory...'
            mv /var/log/ceph /var/log/ceph.bak.\$(date +%s)
        fi
        if [ ! -d /var/log/ceph ]; then
            mkdir -p /var/log/ceph
        fi
        chown ceph:ceph /var/log/ceph
        chmod 750 /var/log/ceph
    "
}

restart_services() {
    local node=$1
    log_info "Restarting Ceph services on $node..."
    ssh -i $SSH_KEY -o StrictHostKeyChecking=no $SSH_USER@$node "
        systemctl restart ceph-mon.target ceph-mgr.target ceph-mds.target ceph-osd.target
    "
}

recover_monitor() {
    local target_node=$1
    local target_id=""
    
    # Determine ID from IP (simple mapping for this lab)
    if [[ "$target_node" == "10.0.40.10" ]]; then target_id="pve-0"; fi
    if [[ "$target_node" == "10.0.40.11" ]]; then target_id="pve-1"; fi
    if [[ "$target_node" == "10.0.40.12" ]]; then target_id="pve-2"; fi
    
    if [[ -z "$target_id" ]]; then
        log_err "Could not determine Node ID for IP $target_node. (Expected 10.0.40.10-12)"
        exit 1
    fi

    log_warn "WARNING: This will WIPE and REBUILD the Ceph Monitor store on $target_id ($target_node)."
    read -p "Are you sure you want to proceed? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Aborted."
        exit 0
    fi

    log_info "Stopping ceph-mon@$target_id..."
    ssh -i $SSH_KEY -o StrictHostKeyChecking=no $SSH_USER@$target_node "systemctl stop ceph-mon@$target_id.service || true"

    log_info "Backing up and cleaning existing store..."
    ssh -i $SSH_KEY -o StrictHostKeyChecking=no $SSH_USER@$target_node "
        rm -f /tmp/monmap /tmp/ceph.mon.keyring /tmp/ceph.client.admin.keyring
        if [ -d /var/lib/ceph/mon/ceph-$target_id ]; then
             mv /var/lib/ceph/mon/ceph-$target_id /var/lib/ceph/mon/ceph-$target_id.bak.\$(date +%s)
        fi
        mkdir -p /var/lib/ceph/mon/ceph-$target_id
        chown ceph:ceph /var/lib/ceph/mon/ceph-$target_id
        chmod 750 /var/lib/ceph/mon/ceph-$target_id
    "

    log_info "Fetching fresh MonMap and Keyring from healthy node ($HEALTHY_NODE)..."
    ssh -i $SSH_KEY -o StrictHostKeyChecking=no $SSH_USER@$target_node "
        scp -o StrictHostKeyChecking=no $HEALTHY_NODE:/etc/ceph/ceph.client.admin.keyring /tmp/ceph.client.admin.keyring
        scp -o StrictHostKeyChecking=no $HEALTHY_NODE:/etc/ceph/ceph.conf /tmp/ceph.conf
        
        ceph --keyring /tmp/ceph.client.admin.keyring --name client.admin mon getmap -o /tmp/monmap
        ceph --keyring /tmp/ceph.client.admin.keyring --name client.admin auth get mon. -o /tmp/ceph.mon.keyring
        
        chown ceph:ceph /tmp/monmap /tmp/ceph.mon.keyring /tmp/ceph.conf
        chmod 644 /tmp/monmap /tmp/ceph.mon.keyring /tmp/ceph.conf
    "

    log_info "Re-initializing Monitor Store..."
    ssh -i $SSH_KEY -o StrictHostKeyChecking=no $SSH_USER@$target_node "
        sudo -u ceph ceph-mon --mkfs -i $target_id --monmap /tmp/monmap --keyring /tmp/ceph.mon.keyring -c /tmp/ceph.conf
        touch /var/lib/ceph/mon/ceph-$target_id/done
        chown ceph:ceph /var/lib/ceph/mon/ceph-$target_id/done
    "

    log_info "Starting Service..."
    ssh -i $SSH_KEY -o StrictHostKeyChecking=no $SSH_USER@$target_node "
        systemctl start ceph-mon@$target_id.service
        rm /tmp/monmap /tmp/ceph.mon.keyring /tmp/ceph.client.admin.keyring /tmp/ceph.conf
    "
    
    log_info "Waiting for service to stabilize..."
    sleep 5
    ssh -i $SSH_KEY -o StrictHostKeyChecking=no $SSH_USER@$target_node "systemctl status ceph-mon@$target_id.service --no-pager"
}

usage() {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  --maintenance    Run maintenance (fix logs, restart services) on ALL nodes."
    echo "  --recover <IP>   Recover a corrupted monitor on a specific node IP."
    echo "  --status         Check cluster status."
    echo "  --help           Show this help message."
}

if [[ $# -eq 0 ]]; then
    usage
    exit 1
fi

case "$1" in
    --maintenance)
        for node in "${ALL_NODES[@]}"; do
            if check_ssh $node; then
                fix_log_permissions $node
                restart_services $node
            fi
        done
        ;;
    --recover)
        if [[ -z "$2" ]]; then
            log_err "Please specify the node IP to recover."
            exit 1
        fi
        recover_monitor $2
        ;;
    --status)
        ssh -i $SSH_KEY -o StrictHostKeyChecking=no $SSH_USER@$HEALTHY_NODE "ceph -s"
        ;;
    *)
        usage
        exit 1
        ;;
esac
