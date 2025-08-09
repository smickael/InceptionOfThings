#!/bin/bash
set -e

 # Main script for deploying GitLab + ArgoCD on K3d
 # Usage: ./run.sh [step_number]
 # If step_number is provided, starts from that step

SCRIPT_DIR="$(dirname "$0")"
STEP_START=${1:-1}

echo "=== Deploying GitLab + ArgoCD on K3d ==="
echo "Starting from step: $STEP_START"

 # Prerequisites check
if [ $STEP_START -le 1 ]; then
    echo "Step 1: Checking prerequisites..."
    "$SCRIPT_DIR/scripts/01-check-prereq.sh"
fi

 # GitLab installation
if [ $STEP_START -le 4 ]; then
    echo "Step 4: Installing GitLab..."
    "$SCRIPT_DIR/scripts/04-install-gitlab.sh"
fi

 # Network and DNS configuration
if [ $STEP_START -le 5 ]; then
    echo "Step 5: Configuring network and DNS..."
    "$SCRIPT_DIR/scripts/05-setup-network.sh"
fi

 # GitLab Personal Access Token generation
if [ $STEP_START -le 6 ]; then
    echo "Step 6: Generating GitLab Personal Access Token..."
    "$SCRIPT_DIR/scripts/06-generate-pat.sh"
fi

 # Import project into GitLab
if [ $STEP_START -le 7 ]; then
    echo "Step 7: Importing project into GitLab..."
    "$SCRIPT_DIR/scripts/07-import-project.sh"
fi

 # CoreDNS configuration for GitLab
if [ $STEP_START -le 8 ]; then
    echo "Step 8: Configuring CoreDNS for GitLab..."
    "$SCRIPT_DIR/scripts/08-config-coredns.sh"
fi

 # ArgoCD-GitLab configuration
if [ $STEP_START -le 9 ]; then
    echo "Step 9: Configuring ArgoCD with GitLab..."
    "$SCRIPT_DIR/scripts/09-setup-argocd-gitlab.sh"
fi

echo "=== Deployment complete ==="
echo "🎯 Service access:"
echo "   ArgoCD: http://argocd.42.fr"
echo "   GitLab: http://gitlab.42.fr"
echo "   Application: http://app.42.fr"
echo ""
