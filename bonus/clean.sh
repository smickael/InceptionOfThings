#!/bin/bash
set -e

echo "=== Full cleanup of GitLab + ArgoCD environment ==="

 # Function to force delete a namespace
force_delete_namespace() {
    local ns=$1
    echo "Deleting namespace $ns..."
    
    if kubectl get namespace "$ns" &> /dev/null; then
    # Remove all resource finalizers
        kubectl get all -n "$ns" -o name | xargs -I {} kubectl patch {} -n "$ns" -p '{"metadata":{"finalizers":[]}}' --type=merge || true
        
    # Force delete the namespace
        kubectl delete namespace "$ns" --force --grace-period=0 || true
        
    # Wait for the namespace to be deleted
        for i in {1..30}; do
            if ! kubectl get namespace "$ns" &> /dev/null; then
                echo "✅ Namespace $ns deleted"
                break
            fi
            sleep 2
        done
    else
    echo "✅ Namespace $ns does not exist"
    fi
}

# Supprimer le cluster K3d
if k3d cluster list | grep -q "iot-cluster"; then
    echo "Deleting K3d cluster..."
    k3d cluster delete iot-cluster
    echo "✅ K3d cluster deleted"
else
    echo "✅ K3d cluster does not exist"
fi

 # Clean /etc/hosts entries
if grep -q "gitlab.42.fr" /etc/hosts; then
    echo "Removing /etc/hosts entries..."
    sudo sed -i '/gitlab.42.fr/d' /etc/hosts
    sudo sed -i '/gitlab.k3d.local/d' /etc/hosts
    echo "✅ /etc/hosts entries cleaned"
fi

 # Clean temporary files
echo "Cleaning temporary files..."
rm -f /tmp/gitlab_pat.txt
rm -rf /tmp/gitlab-certs
rm -f /tmp/gitlab-*.yaml
rm -f /tmp/coredns-*.yaml
rm -f /tmp/hbenyah-playground-*
echo "✅ Temporary files cleaned"

 # Clean unused Docker images
if command -v docker &> /dev/null; then
    echo "Cleaning unused Docker images..."
    docker system prune -f || true
    echo "✅ Docker images cleaned"
fi

echo "🧹 Cleanup complete. You can now rerun ./run.sh"
