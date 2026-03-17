#!/bin/bash
set -e

# Configuration
SSH_KEY=~/.ssh/fs_home_rsa
SSH_USER="root"
ALL_NODES=("10.0.40.10" "10.0.40.11" "10.0.40.12")
NODE_NAMES=("pve-0" "pve-1" "pve-2")
HEALTHY_NODE="10.0.40.10"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_err() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${CYAN}[STEP]${NC} $1"; }

ssh_cmd() {
    local node=$1
    shift
    ssh -i $SSH_KEY -o StrictHostKeyChecking=no -o ConnectTimeout=10 $SSH_USER@$node "$@"
}

check_ssh() {
    local node=$1
    if ! ssh_cmd $node "exit" 2>/dev/null; then
        return 1
    fi
    return 0
}

find_available_node() {
    for node in "${ALL_NODES[@]}"; do
        if check_ssh $node; then
            echo $node
            return 0
        fi
    done
    return 1
}

stop_vms_and_cts() {
    local node=$1
    log_info "Stopping VMs and containers on $node..."
    ssh_cmd $node "
        # Stop all running VMs
        for vmid in \$(qm list 2>/dev/null | awk 'NR>1 {print \$1}'); do
            status=\$(qm status \$vmid 2>/dev/null | awk '{print \$2}')
            if [[ \"\$status\" == \"running\" ]]; then
                echo \"  Stopping VM \$vmid...\"
                qm shutdown \$vmid --timeout 120 2>/dev/null || qm stop \$vmid 2>/dev/null || true
            fi
        done
        
        # Stop all running containers
        for ctid in \$(pct list 2>/dev/null | awk 'NR>1 {print \$1}'); do
            status=\$(pct status \$ctid 2>/dev/null | awk '{print \$2}')
            if [[ \"\$status\" == \"running\" ]]; then
                echo \"  Stopping CT \$ctid...\"
                pct shutdown \$ctid --timeout 60 2>/dev/null || pct stop \$ctid 2>/dev/null || true
            fi
        done
    " 2>/dev/null || true
}

set_ceph_maintenance_flags() {
    log_step "Setting Ceph maintenance flags..."
    local node=$(find_available_node)
    if [[ -z "$node" ]]; then
        log_err "No nodes available"
        return 1
    fi
    
    ssh_cmd $node "
        ceph osd set noout
        ceph osd set norecover
        ceph osd set nobackfill
        ceph osd set norebalance
        ceph osd set pause
    "
    log_info "Ceph maintenance flags set (noout, norecover, nobackfill, norebalance, pause)"
}

unset_ceph_maintenance_flags() {
    log_step "Unsetting Ceph maintenance flags..."
    local node=$(find_available_node)
    if [[ -z "$node" ]]; then
        log_err "No nodes available"
        return 1
    fi
    
    ssh_cmd $node "
        ceph osd unset pause
        ceph osd unset norebalance
        ceph osd unset nobackfill
        ceph osd unset norecover
        ceph osd unset noout
    "
    log_info "Ceph maintenance flags unset"
}

stop_ceph_services() {
    local node=$1
    local node_name=$2
    log_info "Stopping Ceph services on $node_name ($node)..."
    
    ssh_cmd $node "
        # Stop MDS (CephFS metadata server)
        systemctl stop ceph-mds.target 2>/dev/null || true
        
        # Stop OSD
        systemctl stop ceph-osd.target 2>/dev/null || true
        
        # Stop MGR
        systemctl stop ceph-mgr.target 2>/dev/null || true
        
        # Stop MON (last)
        systemctl stop ceph-mon.target 2>/dev/null || true
        
        echo 'Ceph services stopped'
    " 2>/dev/null || true
}

start_ceph_services() {
    local node=$1
    local node_name=$2
    log_info "Starting Ceph services on $node_name ($node)..."
    
    ssh_cmd $node "
        # Start MON first
        systemctl start ceph-mon.target
        sleep 2
        
        # Start MGR
        systemctl start ceph-mgr.target
        sleep 2
        
        # Start OSD
        systemctl start ceph-osd.target
        sleep 2
        
        # Start MDS
        systemctl start ceph-mds.target
        
        echo 'Ceph services started'
    " || true
}

shutdown_node() {
    local node=$1
    local node_name=$2
    log_info "Shutting down $node_name ($node)..."
    ssh_cmd $node "shutdown -h now" 2>/dev/null &
}

wait_for_ceph_healthy() {
    local node=$1
    local max_wait=${2:-300}
    local waited=0
    
    log_info "Waiting for Ceph cluster to become healthy (max ${max_wait}s)..."
    while [[ $waited -lt $max_wait ]]; do
        local health=$(ssh_cmd $node "ceph health 2>/dev/null" || echo "UNKNOWN")
        if [[ "$health" == "HEALTH_OK" ]]; then
            log_info "Ceph cluster is healthy"
            return 0
        fi
        echo -n "."
        sleep 5
        waited=$((waited + 5))
    done
    echo
    log_warn "Ceph did not reach HEALTH_OK within ${max_wait}s (current: $health)"
    return 1
}

wait_for_node_up() {
    local node=$1
    local max_wait=${2:-300}
    local waited=0
    
    log_info "Waiting for $node to come online (max ${max_wait}s)..."
    while [[ $waited -lt $max_wait ]]; do
        if check_ssh $node; then
            log_info "$node is online"
            return 0
        fi
        echo -n "."
        sleep 5
        waited=$((waited + 5))
    done
    echo
    log_err "$node did not come online within ${max_wait}s"
    return 1
}

do_shutdown() {
    log_step "=========================================="
    log_step "PROXMOX CLUSTER CLEAN SHUTDOWN"
    log_step "=========================================="
    
    log_warn "This will shutdown ALL Proxmox nodes in the cluster."
    log_warn "All VMs and containers will be stopped."
    read -p "Are you sure you want to proceed? (yes/N) " -r
    if [[ ! "$REPLY" == "yes" ]]; then
        log_info "Aborted."
        exit 0
    fi
    
    # Step 1: Stop all VMs and containers on all nodes
    log_step "Step 1/4: Stopping all VMs and containers..."
    for i in "${!ALL_NODES[@]}"; do
        if check_ssh "${ALL_NODES[$i]}"; then
            stop_vms_and_cts "${ALL_NODES[$i]}"
        fi
    done
    
    # Step 2: Set Ceph maintenance flags
    log_step "Step 2/4: Setting Ceph maintenance flags..."
    set_ceph_maintenance_flags
    
    # Step 3: Stop Ceph services on each node
    log_step "Step 3/4: Stopping Ceph services..."
    for i in "${!ALL_NODES[@]}"; do
        if check_ssh "${ALL_NODES[$i]}"; then
            stop_ceph_services "${ALL_NODES[$i]}" "${NODE_NAMES[$i]}"
        fi
    done
    
    # Step 4: Shutdown nodes (last node shuts down last)
    log_step "Step 4/4: Shutting down nodes..."
    for i in "${!ALL_NODES[@]}"; do
        if check_ssh "${ALL_NODES[$i]}"; then
            shutdown_node "${ALL_NODES[$i]}" "${NODE_NAMES[$i]}"
            sleep 2
        fi
    done
    
    log_info "=========================================="
    log_info "Shutdown commands sent to all nodes."
    log_info "Nodes will power off shortly."
    log_info "=========================================="
}

do_startup() {
    log_step "=========================================="
    log_step "PROXMOX CLUSTER STARTUP RECOVERY"
    log_step "=========================================="
    log_info "Run this after nodes have been powered on."
    log_info "This will start Ceph services and unset maintenance flags."
    echo
    
    # Check which nodes are available
    log_step "Checking node availability..."
    local available_count=0
    for i in "${!ALL_NODES[@]}"; do
        if check_ssh "${ALL_NODES[$i]}"; then
            log_info "${NODE_NAMES[$i]} (${ALL_NODES[$i]}) is online"
            available_count=$((available_count + 1))
        else
            log_warn "${NODE_NAMES[$i]} (${ALL_NODES[$i]}) is offline"
        fi
    done
    
    if [[ $available_count -eq 0 ]]; then
        log_err "No nodes are available. Please power on the nodes first."
        exit 1
    fi
    
    if [[ $available_count -lt 3 ]]; then
        log_warn "Only $available_count/3 nodes are online."
        read -p "Continue anyway? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Aborted."
            exit 0
        fi
    fi
    
    # Step 1: Start Ceph services on each node
    log_step "Step 1/3: Starting Ceph services..."
    for i in "${!ALL_NODES[@]}"; do
        if check_ssh "${ALL_NODES[$i]}"; then
            start_ceph_services "${ALL_NODES[$i]}" "${NODE_NAMES[$i]}"
        fi
    done
    
    # Wait for services to initialize
    log_info "Waiting for Ceph services to initialize..."
    sleep 10
    
    # Step 2: Unset maintenance flags
    log_step "Step 2/3: Unsetting Ceph maintenance flags..."
    unset_ceph_maintenance_flags
    
    # Step 3: Check cluster health
    log_step "Step 3/3: Checking cluster health..."
    local node=$(find_available_node)
    ssh_cmd $node "ceph -s"
    
    log_info "=========================================="
    log_info "Cluster startup complete."
    log_info "Monitor recovery with: ./hack/fix-ceph.sh --status"
    log_info "=========================================="
}

do_prepare_shutdown() {
    log_step "Preparing cluster for shutdown (without shutting down)..."
    
    # Stop VMs and containers
    log_step "Stopping all VMs and containers..."
    for i in "${!ALL_NODES[@]}"; do
        if check_ssh "${ALL_NODES[$i]}"; then
            stop_vms_and_cts "${ALL_NODES[$i]}"
        fi
    done
    
    # Set maintenance flags
    set_ceph_maintenance_flags
    
    log_info "Cluster is prepared for shutdown."
    log_info "You can now safely power off nodes manually."
    log_info "After reboot, run: $0 --startup"
}

show_status() {
    log_step "Cluster Status"
    echo
    
    # Check node availability
    log_info "Node status:"
    for i in "${!ALL_NODES[@]}"; do
        if check_ssh "${ALL_NODES[$i]}"; then
            echo -e "  ${GREEN}●${NC} ${NODE_NAMES[$i]} (${ALL_NODES[$i]}) - online"
        else
            echo -e "  ${RED}●${NC} ${NODE_NAMES[$i]} (${ALL_NODES[$i]}) - offline"
        fi
    done
    echo
    
    # Check Ceph status
    local node=$(find_available_node)
    if [[ -n "$node" ]]; then
        log_info "Ceph status:"
        ssh_cmd $node "ceph -s"
        echo
        log_info "Ceph flags:"
        ssh_cmd $node "ceph osd dump 2>/dev/null | grep ^flags"
    fi
}

usage() {
    echo "Usage: $0 [options]"
    echo
    echo "Clean shutdown/startup script for Proxmox cluster with Ceph."
    echo "Ensures proper ordering to prevent data corruption."
    echo
    echo "Options:"
    echo "  --shutdown      Stop VMs/CTs, set Ceph flags, shutdown all nodes"
    echo "  --startup       Start Ceph services and unset maintenance flags"
    echo "  --prepare       Prepare for shutdown (stop VMs, set flags) without powering off"
    echo "  --status        Show cluster and node status"
    echo "  --set-flags     Set Ceph maintenance flags only"
    echo "  --unset-flags   Unset Ceph maintenance flags only"
    echo "  --help          Show this help message"
    echo
    echo "Shutdown order:"
    echo "  1. Stop all VMs and containers"
    echo "  2. Set Ceph flags (noout, norecover, nobackfill, norebalance, pause)"
    echo "  3. Stop Ceph services (MDS -> OSD -> MGR -> MON)"
    echo "  4. Shutdown nodes"
    echo
    echo "Startup order:"
    echo "  1. Start Ceph services (MON -> MGR -> OSD -> MDS)"
    echo "  2. Unset Ceph maintenance flags"
    echo "  3. Wait for cluster health"
}

if [[ $# -eq 0 ]]; then
    usage
    exit 1
fi

case "$1" in
    --shutdown)
        do_shutdown
        ;;
    --startup)
        do_startup
        ;;
    --prepare)
        do_prepare_shutdown
        ;;
    --status)
        show_status
        ;;
    --set-flags)
        set_ceph_maintenance_flags
        ;;
    --unset-flags)
        unset_ceph_maintenance_flags
        ;;
    --help)
        usage
        ;;
    *)
        usage
        exit 1
        ;;
esac
