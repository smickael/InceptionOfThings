#!/bin/bash

set -e

echo "=== K3d cluster configuration (Server only) ==="

CLUSTER_NAME="iot-cluster"

 # Remove existing cluster if it exists
if k3d cluster list | grep -q "$CLUSTER_NAME"; then
    echo "Deleting existing K3d cluster..."
    k3d cluster delete "$CLUSTER_NAME"
fi

 # Create K3d cluster exposing only ports 80 and 443 for Traefik
echo "Creating K3d cluster (server only)..."
k3d cluster create "$CLUSTER_NAME" \
    --port "80:80@loadbalancer" \
    --port "443:443@loadbalancer" \
    --agents 0 \
    --servers 1 \
    --wait

 # Configure kubectl
echo "Configuring kubectl..."
k3d kubeconfig merge "$CLUSTER_NAME" --kubeconfig-switch-context

 # Verify cluster is running
echo "Checking cluster status..."
kubectl cluster-info
kubectl get nodes

echo "✅ K3d server-only cluster successfully configured"
