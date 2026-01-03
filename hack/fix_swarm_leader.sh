#!/bin/bash
set -e

# Target Leader
TARGET_LEADER="dkr-srv-0"

# SSH User
SSH_USER="fs"

# Function to get current leader
get_leader() {
    ssh -o StrictHostKeyChecking=no $SSH_USER@$TARGET_LEADER "docker node ls --format '{{.Hostname}} {{.ManagerStatus}}'" | grep "Leader" | awk '{print $1}'
}

echo "Checking Swarm Leadership..."
CURRENT_LEADER=$(get_leader)
echo "Current Leader: $CURRENT_LEADER"

if [ "$CURRENT_LEADER" == "$TARGET_LEADER" ]; then
    echo "✅ $TARGET_LEADER is already the leader."
    exit 0
fi

DEMOTED_NODES=""

while [ "$CURRENT_LEADER" != "$TARGET_LEADER" ]; do
    echo "⚠️  Leader is $CURRENT_LEADER. Demoting..."
    
    # Demote the current leader (run command from target leader to avoid connection loss if possible, or from itself)
    # We run the demote command ON the target leader (dkr-srv-0) which is a manager.
    ssh -o StrictHostKeyChecking=no $SSH_USER@$TARGET_LEADER "docker node demote $CURRENT_LEADER"
    
    DEMOTED_NODES="$DEMOTED_NODES $CURRENT_LEADER"
    
    echo "Waiting for election..."
    sleep 5
    
    CURRENT_LEADER=$(get_leader)
    echo "New Leader: $CURRENT_LEADER"
done

echo "🎉 $TARGET_LEADER is now the Leader!"

# Restore demoted nodes
if [ -n "$DEMOTED_NODES" ]; then
    echo "Restoring demoted nodes to Manager status..."
    for node in $DEMOTED_NODES; do
        echo "Promoting $node..."
        ssh -o StrictHostKeyChecking=no $SSH_USER@$TARGET_LEADER "docker node promote $node"
    done
fi

echo "✅ Swarm Cluster Fixed. $TARGET_LEADER is Leader."
docker node ls
