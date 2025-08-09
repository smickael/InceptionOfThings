#!/bin/bash
set -e

echo "=== Installing ArgoCD ==="

ARGOCD_NAMESPACE="argocd"

 # Create the ArgoCD namespace
echo "Creating ArgoCD namespace..."
kubectl create namespace "$ARGOCD_NAMESPACE" || true

 # Install ArgoCD
echo "Installing ArgoCD..."
kubectl apply -n "$ARGOCD_NAMESPACE" -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

 # Wait for ArgoCD pods to be ready
echo "Waiting for ArgoCD to start..."
kubectl wait --namespace "$ARGOCD_NAMESPACE" --for=condition=available deployment/argocd-server --timeout=600s

 # Patch the argocd-server deployment to add --insecure
echo "Patching argocd-server deployment to enable --insecure (HTTP) ..."
kubectl -n "$ARGOCD_NAMESPACE" patch deployment argocd-server \
  --type='json' \
  -p='[{"op":"add","path":"/spec/template/spec/containers/0/args","value":["argocd-server","--insecure"]}]'
kubectl -n "$ARGOCD_NAMESPACE" rollout restart deployment argocd-server

 # Expose ArgoCD via Traefik Ingress
echo "Configuring ArgoCD exposure via Traefik Ingress..."
kubectl apply -n "$ARGOCD_NAMESPACE" -f "$(dirname "$0")/../confs/argocd-ingress.yaml"

 # Retrieve the ArgoCD admin password
echo "Retrieving ArgoCD admin password..."
ARGOCD_PWD=$(kubectl get secret argocd-initial-admin-secret -n "$ARGOCD_NAMESPACE" -o jsonpath="{.data.password}" | base64 -d)

echo "✅ ArgoCD installed successfully"
echo "   URL: http://argocd.42.fr"
echo "   Login: admin"
echo "   Password: $ARGOCD_PWD"
