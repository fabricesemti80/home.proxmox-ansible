#!/bin/bash
set -e

# Target Manager Node (where we run docker commands)
TARGET_MANAGER="dkr-srv-0"
SSH_USER="fs"

SERVICE_NAME="$1"

if [ -z "$SERVICE_NAME" ]; then
    echo "Usage: $0 <stack_or_service_name>"
    echo "Example: $0 homepage"
    exit 1
fi

echo "🔍 Checking service matching: '$SERVICE_NAME' on $TARGET_MANAGER..."

# 1. Find the full service name
FULL_SERVICE_NAME=$(ssh -o StrictHostKeyChecking=no $SSH_USER@$TARGET_MANAGER "docker service ls --format '{{.Name}}'" | grep "$SERVICE_NAME" | head -n 1)

if [ -z "$FULL_SERVICE_NAME" ]; then
    echo "❌ Service not found matching '$SERVICE_NAME'"
    echo "Available services:"
    ssh -o StrictHostKeyChecking=no $SSH_USER@$TARGET_MANAGER "docker service ls --format '{{.Name}}'"
    exit 1
fi

echo "✅ Found service: $FULL_SERVICE_NAME"
echo ""

# 2. Show Service Status
echo "📊 Service Status:"
ssh -o StrictHostKeyChecking=no $SSH_USER@$TARGET_MANAGER "docker service ls --filter name=$FULL_SERVICE_NAME"
echo ""

# 3. Show Task Status (replicas, errors)
echo "📋 Task Status (Errors/State):"
ssh -o StrictHostKeyChecking=no $SSH_USER@$TARGET_MANAGER "docker service ps $FULL_SERVICE_NAME --no-trunc"
echo ""

# 4. Show Recent Logs
echo "📜 Recent Logs (Last 50 lines):"
ssh -o StrictHostKeyChecking=no $SSH_USER@$TARGET_MANAGER "docker service logs --tail 50 $FULL_SERVICE_NAME"
echo ""
