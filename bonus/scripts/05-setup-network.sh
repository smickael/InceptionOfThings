#!/bin/bash
set -e

echo "=== Simplified network configuration ==="

GITLAB_NAMESPACE="gitlab"

echo "Retrieving GitLab service IP for internal ArgoCD communication..."
GITLAB_SERVICE_IP=$(kubectl get svc -n "$GITLAB_NAMESPACE" gitlab-webservice-default -o jsonpath='{.spec.clusterIP}')
echo "Internal GitLab IP: $GITLAB_SERVICE_IP"

echo "✅ Network configuration complete"
echo "💡 Services accessible via Ingress:"
echo "   - ArgoCD: http://argocd.42.fr"
echo "   - GitLab: http://gitlab.42.fr"
echo "   - App: http://app.42.fr"
 # Patch CoreDNS for gitlab.42.fr
COREDNS_NAMESPACE="kube-system"
COREDNS_CONFIGMAP="coredns"
echo "Retrieving Traefik cluster IP..."
TRAEFIK_IP=$(kubectl get svc -n kube-system traefik -o jsonpath='{.spec.clusterIP}')
GITLAB_HOST="gitlab.42.fr"

echo "Patching CoreDNS ConfigMap for $GITLAB_HOST -> $TRAEFIK_IP..."


 # Robust patch of NodeHosts in CoreDNS ConfigMap
OLD_HOSTS=$(kubectl -n $COREDNS_NAMESPACE get configmap $COREDNS_CONFIGMAP -o jsonpath='{.data.NodeHosts}' | grep -v "$GITLAB_HOST" || true)
NEW_HOSTS=$(echo -e "$TRAEFIK_IP $GITLAB_HOST\n$OLD_HOSTS" | sed ':a;N;$!ba;s/\n/\\n/g')
kubectl -n $COREDNS_NAMESPACE patch configmap $COREDNS_CONFIGMAP --type merge -p "{\"data\":{\"NodeHosts\":\"$NEW_HOSTS\"}}"

echo "Restarting CoreDNS pods..."
kubectl -n $COREDNS_NAMESPACE delete pod -l k8s-app=kube-dns
