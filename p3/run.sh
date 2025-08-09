#!/bin/bash
set -e

SCRIPT_DIR="$(dirname "$0")"
STEP_START=${1:-1}

echo "=== Deploying GitLab + ArgoCD on K3d ==="
echo "Starting from step: $STEP_START"
echo "=== Deployment complete ==="

 # Prerequisites check
if [ $STEP_START -le 1 ]; then
    echo "Step 1: Checking prerequisites..."
    "$SCRIPT_DIR/scripts/01-check-prereq.sh"
fi

 # K3d cluster setup
if [ $STEP_START -le 2 ]; then
    echo "Step 2: Setting up K3d cluster..."
    "$SCRIPT_DIR/scripts/02-setup-k3d.sh"
fi

 # ArgoCD installation
if [ $STEP_START -le 3 ]; then
    echo "Step 3: Installing ArgoCD..."
    "$SCRIPT_DIR/scripts/03-install-argocd.sh"
fi

 # GitHub application deployment
if [ $STEP_START -le 4 ]; then
    echo "Step 4: Deploying GitHub application..."
    "$SCRIPT_DIR/scripts/04-create-argocd-app.sh"
fi

echo "=== Deployment complete ==="
echo "🎯 Service access:"
echo "   ArgoCD: http://argocd.42.fr"
echo "   Application: http://app.42.fr"
echo ""
