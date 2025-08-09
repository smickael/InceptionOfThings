#!/bin/bash
set -e

echo "=== Creating Argo CD application with autosync ==="

kubectl apply -f confs/argocd-application.yaml -n argocd

echo "Waiting for ArgoCD pods to be ready..."
kubectl wait --namespace argocd --for=condition=available --timeout=600s deployment/argocd-server

echo "=== Application configured in Argo CD ==="
echo "ArgoCD UI: http://argocd.42.fr"
echo "Application (once synchronized): http://app.42.fr"
