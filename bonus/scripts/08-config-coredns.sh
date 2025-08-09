#!/bin/bash
set -e

echo "=== Applying GitLab ingress and configuring CoreDNS ==="

GITLAB_NAMESPACE="gitlab"
PROJECT_NAME="hbenyah-playground"
ARGOCD_NAMESPACE="argocd"


 # Apply GitLab ingress (Traefik -> Workhorse 8181, no forced header middleware)
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: gitlab-internal-ingress
  namespace: ${GITLAB_NAMESPACE}
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: web,websecure
    traefik.ingress.kubernetes.io/router.tls: "true"
spec:
  ingressClassName: traefik
  tls:
    - hosts:
        - gitlab.42.fr
        - gitlab-internal.cluster.local
  rules:
    - host: gitlab-internal.cluster.local
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: gitlab-webservice-default
                port:
                  number: 8181
    - host: gitlab.42.fr
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: gitlab-webservice-default
                port:
                  number: 8181
EOF

 # Configure CoreDNS to resolve GitLab hosts to Traefik
echo "=== CoreDNS configuration ==="
TRAEFIK_IP=$(kubectl get svc traefik -n kube-system -o jsonpath='{.spec.clusterIP}')
echo "Traefik IP: $TRAEFIK_IP"

 # Backup current config
kubectl get configmap coredns -n kube-system -o yaml > /tmp/coredns-backup.yaml

cat > /tmp/coredns-config.yaml << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: coredns
  namespace: kube-system
data:
  Corefile: |
    .:53 {
        errors
        health {
           lameduck 5s
        }
        ready
        kubernetes cluster.local in-addr.arpa ip6.arpa {
           pods insecure
           fallthrough in-addr.arpa ip6.arpa
           ttl 30
        }
        hosts {
           $TRAEFIK_IP gitlab.42.fr
           $TRAEFIK_IP gitlab-internal.cluster.local
           fallthrough
        }
        prometheus :9153
        forward . /etc/resolv.conf {
           max_concurrent 1000
        }
        cache 30
        loop
        reload
        loadbalance
    }
EOF

kubectl apply -f /tmp/coredns-config.yaml
kubectl rollout restart deployment/coredns -n kube-system
kubectl rollout status deployment/coredns -n kube-system --timeout=120s

echo "✅ CoreDNS et ingress GitLab configurés."

 # Check that DNS resolution works
echo "=== Checking DNS resolution (via BusyBox) ==="
for i in {1..10}; do
    kubectl run -i --rm --restart=Never busybox-dns-test --image=busybox -- nslookup gitlab.42.fr > /tmp/dns-test.log 2>&1
    if grep -q "$TRAEFIK_IP" /tmp/dns-test.log; then
  echo "✅ DNS resolution gitlab.42.fr -> $TRAEFIK_IP working (BusyBox)"
        break
    else
  echo "⏳ Waiting for DNS propagation (attempt $i/10)..."
        sleep 10
    fi
    if [ $i -eq 10 ]; then
  echo "❌ DNS resolution not working, but continuing..."
    fi
done


 # Step 3: Test connectivity from ArgoCD to GitLab
echo "=== Connectivity test ==="
ARGOCD_POD=$(kubectl get pods -n "$ARGOCD_NAMESPACE" -l app.kubernetes.io/name=argocd-repo-server --no-headers -o custom-columns=":metadata.name" | head -n1 || true)

if [ -n "$ARGOCD_POD" ]; then
  echo "Testing DNS resolution gitlab.42.fr from ArgoCD..."
  if kubectl exec -n "$ARGOCD_NAMESPACE" "$ARGOCD_POD" -c argocd-repo-server -- getent hosts gitlab.42.fr | grep -q "$TRAEFIK_IP"; then
  echo "✅ DNS gitlab.42.fr resolved to $TRAEFIK_IP from ArgoCD"
  else
  echo "❌ DNS gitlab.42.fr not resolved from ArgoCD"
  fi
else
  echo "⚠️  Pod argocd-repo-server not found, skipping ArgoCD DNS test."
fi

echo "Testing connectivity via GitLab external URL (Traefik)..."
GITLAB_URL_HOST="gitlab.42.fr"
GITLAB_REPO_URL_HTTPS="https://$GITLAB_URL_HOST/root/$PROJECT_NAME.git"
GITLAB_REPO_URL_HTTP="http://$GITLAB_URL_HOST/root/$PROJECT_NAME.git"
GITLAB_REPO_URL_INTERNAL="http://gitlab-webservice-default.gitlab.svc.cluster.local:8080/root/$PROJECT_NAME.git"

 # Auth options (optional)
 # Export before running the script:
 #   export GITLAB_HTTP_USER="root"   # or a Deploy Token username
 #   export GITLAB_HTTP_TOKEN="xxxx"  # PAT or Deploy Token (read_repository)
 #   export GIT_SSL_VERIFY=false      # true for valid certs, false for lab (default: false)
SSL_VERIFY="${GIT_SSL_VERIFY:-false}"
AUTH_PREFIX=""
if [ -n "$GITLAB_HTTP_USER" ] && [ -n "$GITLAB_HTTP_TOKEN" ]; then
  AUTH_PREFIX="${GITLAB_HTTP_USER}:${GITLAB_HTTP_TOKEN}@"
fi
GITLAB_REPO_URL_HTTPS_AUTH="https://${AUTH_PREFIX}${GITLAB_URL_HOST}/root/${PROJECT_NAME}.git"
GITLAB_REPO_URL_HTTP_AUTH="http://${AUTH_PREFIX}${GITLAB_URL_HOST}/root/${PROJECT_NAME}.git"

 # Check project visibility via API (helps diagnose 403 due to 'Require sign-in')
PROJECT_URLENC="root%2F${PROJECT_NAME}"


API_RAW=$(kubectl run -i --rm --restart=Never curl-api --image=curlimages/curl -- \
  -k -s -o /dev/null -w "%{http_code}" \
  "https://${GITLAB_URL_HOST}/api/v4/projects/${PROJECT_URLENC}" 2>&1)
API_CODE=$(echo "$API_RAW" | grep -oE '^[0-9]+')

if [ -z "$API_CODE" ]; then
  echo "ℹ️  API: Code HTTP non trouvé, sortie brute :"
  echo "$API_RAW"
else
  case "$API_CODE" in
  200) echo "ℹ️  API: Project publicly accessible (200)";;
  404) echo "ℹ️  API: Project not found publicly (404) -> private or wrong path";;
  401) echo "ℹ️  API: Auth required globally (401) -> 'Require sign-in' likely active";;
  *)   echo "ℹ️  API: Unexpected code: $API_CODE";;
  esac
fi

 # Precise probes of Git smart HTTP endpoint with proper headers
echo "=== Probing git endpoint (HTTP) ==="
HTTP_GIT_CODE=$(
  kubectl run -i --rm --restart=Never curl-http-git --image=curlimages/curl -- \
    -s -o /dev/null -w "%{http_code}" -L \
    -A "git/2.44.0" \
    -H "Accept: application/x-git-upload-pack-advertisement" \
    -H "Git-Protocol: version=2" \
    "http://$GITLAB_URL_HOST/root/$PROJECT_NAME.git/info/refs?service=git-upload-pack" 2>/dev/null || true
)
HTTP_CODE_ONLY=$(echo "$HTTP_GIT_CODE" | grep -oE '^[0-9]+')
echo "HTTP code for /info/refs (HTTP): ${HTTP_CODE_ONLY:-none}"

echo "=== Testing git clone via HTTP (Traefik) ==="
set +e
CLONE_OUTPUT=$(kubectl run -i --rm --restart=Never git-http-clone --image=alpine/git -- clone --depth 1 "http://$GITLAB_URL_HOST/root/$PROJECT_NAME.git" /tmp/test-clone 2>&1)
set -e
if echo "$CLONE_OUTPUT" | grep -q "Cloning into"; then
  echo "✅ git clone HTTP via Traefik OK : http://$GITLAB_URL_HOST/root/$PROJECT_NAME.git"
else
  echo "❌ git clone HTTP via Traefik failed : http://$GITLAB_URL_HOST/root/$PROJECT_NAME.git"
  echo "--- git clone error details ---"
  echo "$CLONE_OUTPUT"
fi
echo "HTTP code for /info/refs (HTTP): ${HTTP_CODE_ONLY:-none}"

echo "=== Testing git clone via HTTP (Traefik) ==="
set +e
CLONE_OUTPUT=$(kubectl run -i --rm --restart=Never git-http-clone --image=alpine/git -- clone --depth 1 "http://$GITLAB_URL_HOST/root/$PROJECT_NAME.git" /tmp/test-clone 2>&1)
set -e
if echo "$CLONE_OUTPUT" | grep -q "Cloning into"; then
  echo "✅ git clone HTTP via Traefik OK : http://$GITLAB_URL_HOST/root/$PROJECT_NAME.git"
else
  echo "❌ git clone HTTP via Traefik failed : http://$GITLAB_URL_HOST/root/$PROJECT_NAME.git"
  echo "--- git clone error details ---"
  echo "$CLONE_OUTPUT"
fi
