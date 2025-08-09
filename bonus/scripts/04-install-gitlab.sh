#!/bin/bash
set -e

echo "=== Installing GitLab ==="

GITLAB_NAMESPACE="gitlab"

echo "Creating GitLab namespace..."
kubectl create namespace "$GITLAB_NAMESPACE" || true

echo "Adding GitLab Helm repo..."
helm repo add gitlab https://charts.gitlab.io/ || true
helm repo update

echo "Applying custom GitLab resources..."
kubectl apply -f "$(dirname "$0")/../confs/gitlab-pvc.yaml"
kubectl apply -f "$(dirname "$0")/../confs/gitlab-configmap.yaml"

echo "Installing GitLab via Helm..."
helm upgrade --install gitlab gitlab/gitlab \
    --namespace "$GITLAB_NAMESPACE" \
    -f "$(dirname "$0")/../confs/gitlab-values.yaml" \
    --timeout 20m \
    --wait

echo "Waiting for GitLab to start..."
kubectl wait --namespace "$GITLAB_NAMESPACE" --for=condition=available deployment/gitlab-webservice-default --timeout=1200s

echo "Configuring GitLab exposure via Traefik Ingress..."
kubectl apply -n "$GITLAB_NAMESPACE" -f "$(dirname "$0")/../confs/gitlab-traefik-ingress.yaml"

if ! grep -q "gitlab.42.fr" /etc/hosts; then
    echo "Adding gitlab.42.fr to /etc/hosts..."
    echo "127.0.0.1 gitlab.42.fr" | sudo tee -a /etc/hosts
fi

echo "Retrieving GitLab root password..."
GITLAB_ROOT_PWD=$(kubectl get secret -n "$GITLAB_NAMESPACE" gitlab-gitlab-initial-root-password -o jsonpath="{.data.password}" | base64 -d)
echo "GitLab root password: $GITLAB_ROOT_PWD"

echo "✅ GitLab installed successfully"
echo "   URL: http://gitlab.42.fr"
echo "   Login: root"
echo "   Password: $GITLAB_ROOT_PWD"
