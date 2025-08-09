#!/bin/bash
set -e

echo "=== Generating GitLab Personal Access Token ==="

GITLAB_NAMESPACE="gitlab"

echo "[DEBUG] Waiting for GitLab webservice pod to be ready..."
kubectl wait --for=condition=Ready pod -l app=webservice -n "$GITLAB_NAMESPACE" --timeout=300s || { echo "[ERROR] Timeout waiting for webservice pod." >&2; exit 1; }

WEBSERVICE_POD=$(kubectl get pods -n "$GITLAB_NAMESPACE" -l app=webservice --field-selector=status.phase=Running --no-headers -o custom-columns=":metadata.name" | head -n1)
if [ -z "$WEBSERVICE_POD" ]; then
    echo "[ERROR] No webservice pod found, aborting." >&2
    kubectl get pods -n "$GITLAB_NAMESPACE" -l app=webservice
    exit 1
fi
echo "[DEBUG] Webservice pod: $WEBSERVICE_POD"

TOKEN_NAME="argo-token-$(date +%Y%m%d-%H%M%S)"
SCOPES="api,read_repository,write_repository"
EXPIRES_AT="$(date -d '+1 year' +%Y-%m-%d)"

cat > /tmp/gitlab_create_token.rb << EOF
#!/usr/bin/env ruby
require '/srv/gitlab/config/environment'
user = User.find_by(username: 'root')
exit(1) unless user
user.personal_access_tokens.where(name: '$TOKEN_NAME').destroy_all
token = user.personal_access_tokens.create!(name: '$TOKEN_NAME', scopes: '$SCOPES'.split(','), expires_at: Date.parse('$EXPIRES_AT'))
puts(token.token || 'ERROR')
EOF

kubectl exec -n "$GITLAB_NAMESPACE" "$WEBSERVICE_POD" -c webservice -- rm -f /tmp/create_token.rb 2>/dev/null || true
if kubectl cp /tmp/gitlab_create_token.rb "$GITLAB_NAMESPACE/$WEBSERVICE_POD":/tmp/create_token.rb -c webservice 2>/dev/null; then
    echo "[DEBUG] Ruby script copied to pod. Executing..."
    RUBY_OUTPUT=$(kubectl exec -n "$GITLAB_NAMESPACE" "$WEBSERVICE_POD" -c webservice -- timeout 60 bash -c "cd /srv/gitlab && RAILS_ENV=production bundle exec ruby /tmp/create_token.rb" 2>&1)
    PAT=$(echo "$RUBY_OUTPUT" | tail -n1)
    echo "[DEBUG] Ruby script output: $RUBY_OUTPUT"
    kubectl exec -n "$GITLAB_NAMESPACE" "$WEBSERVICE_POD" -c webservice -- rm -f /tmp/create_token.rb 2>/dev/null || true
else
    echo "[ERROR] Error copying Ruby script to pod." >&2
    PAT="ERROR"
fi
rm -f /tmp/gitlab_create_token.rb

if [ -z "$PAT" ] || [ "$PAT" = "ERROR" ] || ! [[ "$PAT" =~ ^glpat- ]]; then
    echo "[ERROR] Error generating PAT: $PAT" >&2
    exit 1
fi

echo "[SUCCESS] PAT generated: ${PAT:0:10}..."
echo "$PAT" > /tmp/gitlab_pat.txt
echo "[INFO] PAT saved in /tmp/gitlab_pat.txt"
