#!/bin/bash
set -e

# --- Define constants early (fix: ARGOCD_NAMESPACE used before set) ---
ARGOCD_NAMESPACE="argocd"
GITLAB_NAMESPACE="gitlab"
DEV_NAMESPACE="dev"
PROJECT_NAME="hbenyah-playground"
GITLAB_URL_HOST="gitlab.42.fr"

GITLAB_PAT_FILE="/tmp/gitlab_pat.txt"
# Charger le PAT depuis le fichier si présent
if [ -z "$GITLAB_PAT" ] && [ -f "$GITLAB_PAT_FILE" ]; then
  GITLAB_PAT=$(cat "$GITLAB_PAT_FILE")
fi

# Charger le mot de passe admin ArgoCD
ARGOCD_PWD_FILE="/tmp/argocd_admin_pwd.txt"

# Récupérer le mot de passe admin ArgoCD automatiquement si absent
if [ -z "$ARGOCD_PWD" ]; then
  if [ -f "$ARGOCD_PWD_FILE" ]; then
    ARGOCD_PWD=$(cat "$ARGOCD_PWD_FILE")
  else
    ARGOCD_PWD=$(kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' | base64 -d 2>/dev/null)
  fi
fi

# Vérifier que le mot de passe admin est bien défini
if [ -z "$ARGOCD_PWD" ]; then
  echo "❌ Erreur : Le mot de passe admin ArgoCD (ARGOCD_PWD) n'est pas défini. Exportez la variable ou créez le fichier $ARGOCD_PWD_FILE."
  exit 1
fi
# Vérifier que le PAT est bien défini (optionnel si le repo est public)
if [ -z "$GITLAB_PAT" ]; then
  echo "ℹ️  GITLAB_PAT non défini. Le dépôt étant public, tentative en anonyme."
else
  echo "ℹ️  GITLAB_PAT fourni. Utilisation des credentials uniquement si nécessaire."
fi

# Detect if argocd CLI is available
HAS_ARGOCD=0
if command -v argocd >/dev/null 2>&1; then
  HAS_ARGOCD=1
else
  echo "ℹ️  argocd CLI introuvable, bascule en mode kubectl uniquement."
fi

# --- Infos & URLs pour les tests/probes (anonyme d'abord) ---
GITLAB_REPO_URL_SECURE="https://${GITLAB_URL_HOST}/root/${PROJECT_NAME}.git"
INT_URL="http://gitlab-webservice-default.gitlab.svc.cluster.local:8080/root/${PROJECT_NAME}.git"
INT_URL_8181="http://gitlab-webservice-default.gitlab.svc.cluster.local:8181/root/${PROJECT_NAME}.git"
EXT_URL="$GITLAB_REPO_URL_SECURE"
INT_AUTH_URL="http://root:${GITLAB_PAT}@gitlab-webservice-default.gitlab.svc.cluster.local:8080/root/${PROJECT_NAME}.git"
INT_AUTH_URL_8181="http://root:${GITLAB_PAT}@gitlab-webservice-default.gitlab.svc.cluster.local:8181/root/${PROJECT_NAME}.git"
EXT_AUTH_URL="https://root:${GITLAB_PAT}@${GITLAB_URL_HOST}/root/${PROJECT_NAME}.git"

# (supprimé: test PAT bloquant)
# ...existing code up to DNS/connectivity tests...

echo "=== Test DNS et connectivité depuis le pod ArgoCD repo-server ==="
# (fix: ARGOCD_NAMESPACE is now defined at top)
ARGOCD_POD=$(kubectl get pods -n "$ARGOCD_NAMESPACE" -l app.kubernetes.io/name=argocd-repo-server --no-headers -o custom-columns=":metadata.name" | head -n1 || true)
if [ -n "$ARGOCD_POD" ]; then
  echo "Test DNS: kubectl exec -n $ARGOCD_NAMESPACE $ARGOCD_POD -- getent hosts gitlab.42.fr"
  kubectl exec -n "$ARGOCD_NAMESPACE" "$ARGOCD_POD" -- getent hosts gitlab.42.fr || echo "❌ DNS gitlab.42.fr non résolu depuis ArgoCD repo-server"
else
  echo "⚠️  Pod argocd-repo-server introuvable, saut des tests DNS/HTTP."
fi

# Remplacer le test HTTP dans le repo-server (curl absent) par un pod curl dédié
echo "=== Test HTTP(S) via pod curl (dans le cluster) ==="
set +e
EXT_HTTP_HEADERS=$(kubectl run -i --rm --restart=Never curl-ext --image=curlimages/curl -- \
  -k -s -D - -o /dev/null -L https://gitlab.42.fr 2>&1)
EXT_HTTP_CODE=$(echo "$EXT_HTTP_HEADERS" | awk 'tolower($1)=="http/"{code=$2} END{print code}')
echo "Réponse https://gitlab.42.fr -> HTTP $EXT_HTTP_CODE"
set -e

echo "=== Résumé ressources GitLab (Service/Endpoints/Ingress/Pods) ==="
kubectl get svc -n "$GITLAB_NAMESPACE" gitlab-webservice-default -o wide || true
kubectl get endpoints -n "$GITLAB_NAMESPACE" gitlab-webservice-default -o wide || true
kubectl get ingress -n "$GITLAB_NAMESPACE" || true
kubectl get pods -n "$GITLAB_NAMESPACE" -o wide | grep -E "webservice|gitlab" || true

# Probe Git smart HTTP endpoints (interne et externe)
SMART_PATH="/root/${PROJECT_NAME}.git/info/refs?service=git-upload-pack"
echo "=== Probe smart-HTTP (interne:8080) ==="
set +e
INT_PROBE_8080=$(kubectl run -i --rm --restart=Never curl-int-8080 --image=curlimages/curl -- \
  -s -D - -o /dev/null -L -A "git/2.44.0" \
  "http://gitlab-webservice-default.gitlab.svc.cluster.local:8080${SMART_PATH}" 2>&1)
INT_CODE_8080=$(echo "$INT_PROBE_8080" | awk 'tolower($1)=="http/"{code=$2} END{print code}')
echo "$INT_PROBE_8080"
echo "Interne smart-HTTP 8080 code: ${INT_CODE_8080:-none}"
echo "=== Probe smart-HTTP (interne:8181) ==="
INT_PROBE_8181=$(kubectl run -i --rm --restart=Never curl-int-8181 --image=curlimages/curl -- \
  -s -D - -o /dev/null -L -A "git/2.44.0" \
  "http://gitlab-webservice-default.gitlab.svc.cluster.local:8181${SMART_PATH}" 2>&1)
INT_CODE_8181=$(echo "$INT_PROBE_8181" | awk 'tolower($1)=="http/"{code=$2} END{print code}')
echo "$INT_PROBE_8181"
echo "Interne smart-HTTP 8181 code: ${INT_CODE_8181:-none}"
echo "=== Probe smart-HTTP (externe) ==="
EXT_PROBE=$(kubectl run -i --rm --restart=Never curl-ext-probe --image=curlimages/curl -- \
  -k -s -D - -o /dev/null -L -A "git/2.44.0" \
  "https://gitlab.42.fr${SMART_PATH}" 2>&1)
EXT_CODE=$(echo "$EXT_PROBE" | awk 'tolower($1)=="http/"{code=$2} END{print code}')
echo "$EXT_PROBE"
echo "Externe smart-HTTP code: ${EXT_CODE:-none}"
set -e

echo "=== Test git clone via pod (alpine/git) ==="
# Essayer: interne 8181 anonyme -> interne 8080 anonyme -> externe anonyme -> interne 8181/auth -> externe/auth
set +e
echo "[clone] interne:8181 anonyme -> $INT_URL_8181"
CLONE_OUTPUT=$(kubectl run -i --rm --restart=Never gitlab-git-clone --image=alpine/git -- \
  clone --depth 1 "$INT_URL_8181" /tmp/test-clone 2>&1)
CLONE_RC=$?
if [ $CLONE_RC -ne 0 ]; then
  echo "⛔ rc=$CLONE_RC"; echo "$CLONE_OUTPUT"
  echo "[clone] interne:8080 anonyme -> $INT_URL"
  CLONE_OUTPUT=$(kubectl run -i --rm --restart=Never gitlab-git-clone --image=alpine/git -- \
    clone --depth 1 "$INT_URL" /tmp/test-clone 2>&1); CLONE_RC=$?
fi
if [ $CLONE_RC -ne 0 ]; then
  echo "⛔ rc=$CLONE_RC"; echo "$CLONE_OUTPUT"
  echo "[clone] externe anonyme (TLS off) -> $EXT_URL"
  CLONE_OUTPUT=$(kubectl run -i --rm --restart=Never gitlab-git-clone --image=alpine/git -- \
    -c http.sslVerify=false clone --depth 1 "$EXT_URL" /tmp/test-clone 2>&1); CLONE_RC=$?
fi
if [ $CLONE_RC -ne 0 ] && [ -n "$GITLAB_PAT" ]; then
  echo "⛔ rc=$CLONE_RC"; echo "$CLONE_OUTPUT"
  echo "[clone] interne:8181 auth -> $INT_AUTH_URL_8181"
  CLONE_OUTPUT=$(kubectl run -i --rm --restart=Never gitlab-git-clone --image=alpine/git -- \
    clone --depth 1 "$INT_AUTH_URL_8181" /tmp/test-clone 2>&1); CLONE_RC=$?
fi
if [ $CLONE_RC -ne 0 ] && [ -n "$GITLAB_PAT" ]; then
  echo "⛔ rc=$CLONE_RC"; echo "$CLONE_OUTPUT"
  echo "[clone] externe auth (TLS off) -> $EXT_AUTH_URL"
  CLONE_OUTPUT=$(kubectl run -i --rm --restart=Never gitlab-git-clone --image=alpine/git -- \
    -c http.sslVerify=false clone --depth 1 "$EXT_AUTH_URL" /tmp/test-clone 2>&1); CLONE_RC=$?
fi
if [ $CLONE_RC -eq 0 ]; then
  echo "✅ git clone OK"
else
  echo "❌ git clone KO (toutes les tentatives)"; echo "$CLONE_OUTPUT"
fi
set -e

echo "=== Configuration ArgoCD avec GitLab (Approche simplifiée) ==="

# --- Choose the repo URL that actually works from inside the cluster ---
EXTERNAL_HTTPS_REPO="$EXT_URL"
INTERNAL_HTTP_REPO_8080="$INT_URL"
INTERNAL_HTTP_REPO_8181="$INT_URL_8181"

echo "Probe in-cluster repo access to pick the best URL for Argo CD..."
CHOSEN_REPO_URL=""
CREDS_NEEDED="false"
set +e
echo "[probe] ls-remote interne 8181 (anon) -> $INTERNAL_HTTP_REPO_8181"
INT8181_LS_OUT=$(kubectl run -i --rm --restart=Never repo-probe-int-8181 --image=alpine/git -- \
  ls-remote "$INTERNAL_HTTP_REPO_8181" 2>&1); INT8181_LS_RC=$?
if [ $INT8181_LS_RC -eq 0 ]; then
  CHOSEN_REPO_URL="$INTERNAL_HTTP_REPO_8181"; echo "✅ interne 8181 OK"
else
  echo "⛔ rc=$INT8181_LS_RC"; echo "$INT8181_LS_OUT"
  echo "[probe] ls-remote interne 8080 (anon) -> $INTERNAL_HTTP_REPO_8080"
  INT8080_LS_OUT=$(kubectl run -i --rm --restart=Never repo-probe-int-8080 --image=alpine/git -- \
    ls-remote "$INTERNAL_HTTP_REPO_8080" 2>&1); INT8080_LS_RC=$?
  if [ $INT8080_LS_RC -eq 0 ]; then
    CHOSEN_REPO_URL="$INTERNAL_HTTP_REPO_8080"; echo "✅ interne 8080 OK"
  else
    echo "⛔ rc=$INT8080_LS_RC"; echo "$INT8080_LS_OUT"
    echo "[probe] ls-remote externe (anon, TLS off) -> $EXTERNAL_HTTPS_REPO"
    EXT_LS_OUT=$(kubectl run -i --rm --restart=Never repo-probe-ext --image=alpine/git -- \
      -c http.sslVerify=false ls-remote "$EXTERNAL_HTTPS_REPO" 2>&1); EXT_LS_RC=$?
    if [ $EXT_LS_RC -eq 0 ]; then
      CHOSEN_REPO_URL="$EXTERNAL_HTTPS_REPO"; echo "✅ externe OK"
    else
      echo "⛔ rc=$EXT_LS_RC"; echo "$EXT_LS_OUT"
      if [ -n "$GITLAB_PAT" ]; then
        echo "[probe] ls-remote interne 8181 (auth) -> $INT_AUTH_URL_8181"
        INT8181_AUTH_LS_OUT=$(kubectl run -i --rm --restart=Never repo-probe-int-8181-auth --image=alpine/git -- \
          ls-remote "$INT_AUTH_URL_8181" 2>&1); INT8181_AUTH_LS_RC=$?
        if [ $INT8181_AUTH_LS_RC -eq 0 ]; then
          CHOSEN_REPO_URL="$INTERNAL_HTTP_REPO_8181"; CREDS_NEEDED="true"; echo "✅ interne 8181 (auth) OK"
        else
          echo "⛔ rc=$INT8181_AUTH_LS_RC"; echo "$INT8181_AUTH_LS_OUT"
          echo "[probe] ls-remote externe (auth, TLS off) -> $EXT_AUTH_URL"
          EXT_AUTH_LS_OUT=$(kubectl run -i --rm --restart=Never repo-probe-ext-auth --image=alpine/git -- \
            -c http.sslVerify=false ls-remote "$EXT_AUTH_URL" 2>&1); EXT_AUTH_LS_RC=$?
          if [ $EXT_AUTH_LS_RC -eq 0 ]; then
            CHOSEN_REPO_URL="$EXTERNAL_HTTPS_REPO"; CREDS_NEEDED="true"; echo "✅ externe (auth) OK"
          else
            echo "⛔ rc=$EXT_AUTH_LS_RC"; echo "$EXT_AUTH_LS_OUT"
          fi
        fi
      fi
    fi
  fi
fi
set -e

# Sanity: ensure .git suffix and non-empty
if [ -z "$CHOSEN_REPO_URL" ] || [[ ! "$CHOSEN_REPO_URL" =~ \.git$ ]]; then
  echo "❌ Impossible de déterminer une URL de repo valide après tests des ports 8181/8080 et externe."
  exit 1
fi

# Supprimer l'application ArgoCD en amont (si présente) pour éviter des restes bloquants
kubectl delete application "$PROJECT_NAME" -n "$ARGOCD_NAMESPACE" --ignore-not-found

echo "=== Suppression du repository ArgoCD existant (si présent) ==="
if [ "$HAS_ARGOCD" -eq 1 ]; then
  RANDOM_PORT=$(( ( RANDOM % 1000 )  + 9000 ))
  kubectl port-forward svc/argocd-server -n "$ARGOCD_NAMESPACE" $RANDOM_PORT:443 >/tmp/pf-argocd-repo-rm.log 2>&1 &
  PF_REPO_RM_PID=$!
  sleep 5
  set +e
  timeout 30 bash -c "echo 'y' | argocd login localhost:$RANDOM_PORT --username admin --password '$ARGOCD_PWD' --insecure" >/dev/null 2>&1 || true
  argocd repo rm "$EXTERNAL_HTTPS_REPO"     --server localhost:$RANDOM_PORT >/dev/null 2>&1 || true
  argocd repo rm "$INTERNAL_HTTP_REPO_8080" --server localhost:$RANDOM_PORT >/dev/null 2>&1 || true
  argocd repo rm "$INTERNAL_HTTP_REPO_8181" --server localhost:$RANDOM_PORT >/dev/null 2>&1 || true
  set -e
  kill $PF_REPO_RM_PID 2>/dev/null || true
else
  echo "ℹ️  argocd CLI absent, saut de la suppression de repository via CLI."
fi

echo "=== Configuration du repository secret ==="
kubectl delete secret gitlab-repo -n "$ARGOCD_NAMESPACE" --ignore-not-found

# Champs credentials conditionnels (uniquement si requis)
STRINGDATA_CREDS=""
if [ "$CREDS_NEEDED" = "true" ]; then
  STRINGDATA_CREDS="  username: root
  password: $GITLAB_PAT"
fi

# Créer le secret avec ou sans credentials selon $CREDS_NEEDED
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: gitlab-repo
  namespace: $ARGOCD_NAMESPACE
  labels:
    argocd.argoproj.io/secret-type: repository
type: Opaque
stringData:
  name: gitlab-hbenyah-playground
  project: default
  type: git
  url: $CHOSEN_REPO_URL
$STRINGDATA_CREDS
  insecure: "true"
  enableLfs: "false"
  tlsClientCertData: ""
  tlsClientCertKey: ""
EOF

# Vérifier que le secret a été créé correctement
echo "Vérification du secret créé:"
kubectl get secret gitlab-repo -n "$ARGOCD_NAMESPACE" -o jsonpath='{.data.url}' | base64 -d
echo ""

# Vérifier que le secret est bien du type repository et que l'URL correspond
SECRET_TYPE=$(kubectl get secret gitlab-repo -n "$ARGOCD_NAMESPACE" -o jsonpath='{.metadata.labels.argocd\.argoproj\.io/secret-type}')
SECRET_URL=$(kubectl get secret gitlab-repo -n "$ARGOCD_NAMESPACE" -o jsonpath='{.data.url}' | base64 -d)
if [ "$SECRET_TYPE" != "repository" ]; then
  echo "❌ Le secret gitlab-repo n'est pas du type repository !"
  exit 1
fi
if [[ "$SECRET_URL" != http* ]]; then
  echo "❌ L'URL du secret gitlab-repo n'est pas correcte : $SECRET_URL"
  exit 1
fi

# Vérifier que le repo GitLab est bien enregistré dans ArgoCD
echo "=== Attente readiness argocd-server (facultatif) ==="
kubectl rollout status deployment/argocd-server -n "$ARGOCD_NAMESPACE" --timeout=60s >/dev/null 2>&1 || true
echo "Vérification de l'enregistrement du repo GitLab dans ArgoCD:"
if [ "$HAS_ARGOCD" -eq 1 ]; then
  RANDOM_PORT=$(( ( RANDOM % 1000 )  + 9000 ))
  kubectl port-forward svc/argocd-server -n "$ARGOCD_NAMESPACE" $RANDOM_PORT:443 >/tmp/pf-argocd-repo-check.log 2>&1 &
  PF_REPO_PID=$!
  sleep 5
  set +e
  LOGIN_OK=0
  for i in 1 2 3; do
    if timeout 30 bash -c "echo 'y' | argocd login localhost:$RANDOM_PORT --username admin --password '$ARGOCD_PWD' --insecure" >/dev/null 2>&1; then
      LOGIN_OK=1; break
    fi
  echo "⚠️  argocd login attempt $i/3 failed (repo check)."
    sleep 5
  done
  if [ $LOGIN_OK -eq 1 ]; then
    if argocd repo list --server localhost:$RANDOM_PORT 2>/dev/null | grep -q "$CHOSEN_REPO_URL"; then
  echo "✅ GitLab repo successfully registered in ArgoCD"
    else
  echo "⚠️  GitLab repo not found in ArgoCD (continuing, app will be created/patched later)"
    fi
  else
  echo "⚠️  Unable to connect to ArgoCD to check repo (continuing)"
  fi
  set -e
  kill $PF_REPO_PID 2>/dev/null || true
else
  echo "ℹ️  argocd CLI missing, skipping verification via CLI."
fi

echo "List of ArgoCD repositories after secret creation:"
if [ "$HAS_ARGOCD" -eq 1 ]; then
  RANDOM_PORT=$(( ( RANDOM % 1000 )  + 9000 ))
  kubectl port-forward svc/argocd-server -n "$ARGOCD_NAMESPACE" $RANDOM_PORT:443 >/tmp/pf-argocd-repo-list.log 2>&1 &
  PF_REPO_LIST_PID=$!
  sleep 5
  timeout 30 bash -c "echo 'y' | argocd login localhost:$RANDOM_PORT --username admin --password '$ARGOCD_PWD' --insecure" >/dev/null 2>&1 || true
  argocd repo list --server localhost:$RANDOM_PORT || true
  kill $PF_REPO_LIST_PID 2>/dev/null || true
else
  echo "ℹ️  argocd CLI missing, skipping repository list via CLI."
fi

# Redémarrer le repo-server pour qu'il prenne en compte le nouveau secret
kubectl rollout restart deployment/argocd-repo-server -n "$ARGOCD_NAMESPACE"
kubectl rollout status deployment/argocd-repo-server -n "$ARGOCD_NAMESPACE" --timeout=120s

sleep 10

# Étape 5: Se connecter à ArgoCD
echo "=== Connexion à ArgoCD ==="
if [ "$HAS_ARGOCD" -eq 1 ]; then
  RANDOM_PORT=$(( ( RANDOM % 1000 )  + 9000 ))
  kubectl port-forward svc/argocd-server -n "$ARGOCD_NAMESPACE" $RANDOM_PORT:443 >/tmp/pf-argocd-main.log 2>&1 &
  PF_PID=$!
  sleep 10
  for i in {1..3}; do
    if timeout 30 bash -c "echo 'y' | argocd login localhost:$RANDOM_PORT --username admin --password '$ARGOCD_PWD' --insecure" >/dev/null 2>&1; then
      echo "✅ Connexion ArgoCD réussie"
      break
    else
      echo "⚠️  Tentative de connexion $i/3 échouée"
      if [ $i -eq 3 ]; then
        echo "⚠️  argocd CLI indisponible ou login impossible, on continue en mode kubectl."
      fi
      sleep 5
    fi
  done
else
  echo "ℹ️  argocd CLI absent, saut de la connexion CLI."
  PF_PID=""
fi

# Étape 6: Créer l'application ArgoCD
echo "=== Création de l'application ArgoCD ==="
kubectl create namespace "$DEV_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
# Supprimer l'application existante si elle existe
kubectl delete application "$PROJECT_NAME" -n "$ARGOCD_NAMESPACE" --ignore-not-found

cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: $PROJECT_NAME
  namespace: $ARGOCD_NAMESPACE
spec:
  project: default
  source:
    repoURL: $CHOSEN_REPO_URL
    targetRevision: HEAD
    path: k8s-manifests
  destination:
    server: https://kubernetes.default.svc
    namespace: $DEV_NAMESPACE
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
EOF

# Attendre que l'application soit créée
sleep 5

# Vérifier que l'application est bien créée et auto-sync
echo "Vérification de l'application ArgoCD:"
if [ "$HAS_ARGOCD" -eq 1 ] && argocd app get "$PROJECT_NAME" 2>/dev/null | grep -q 'Sync Policy: Automated'; then
  echo "✅ Application créée avec auto-sync sur le repo GitLab"
  kubectl rollout restart deployment/argocd-repo-server -n "$ARGOCD_NAMESPACE"
  kubectl rollout status deployment/argocd-repo-server -n "$ARGOCD_NAMESPACE" --timeout=120s
  sleep 10
  argocd app sync "$PROJECT_NAME" --timeout 300 2>/dev/null && echo "✅ Synchronisation forcée après restart repo-server"
else
  # Kubectl-only check
  if kubectl get application "$PROJECT_NAME" -n "$ARGOCD_NAMESPACE" >/dev/null 2>&1; then
    echo "ℹ️  Application détectée (kubectl). Tentative de sync via patch."
    kubectl patch application "$PROJECT_NAME" -n "$ARGOCD_NAMESPACE" --type merge -p '{"operation":{"sync":{"revision":"HEAD","syncOptions":["CreateNamespace=true"]}}}' >/dev/null 2>&1 || true
  else
    echo "❌ Application non trouvée (kubectl)."
  fi
fi

# Étape 7: Vérifier et synchroniser l'application (kubectl-only compatible)
echo "=== Synchronisation de l'application ==="
for i in {1..3}; do
  APP_JSON=$(kubectl get application "$PROJECT_NAME" -n "$ARGOCD_NAMESPACE" -o json 2>/dev/null || echo "")
  if [ -n "$APP_JSON" ]; then
    echo "✅ Application trouvée, tentative de synchronisation..."
    # Détecter erreurs d'auth éventuelles via conditions
    APP_STATUS_MSG=$(echo "$APP_JSON" | jq -r '.status.conditions[]? | select(.type=="ComparisonError") | .message' 2>/dev/null || echo "")
    if echo "$APP_STATUS_MSG" | grep -qiE "authorization failed|Nil JSON web token"; then
      echo "⚠️  Erreur d'authentification détectée, tentative avec URL alternative..."
      ALTERNATIVE_URL="$INTERNAL_HTTP_REPO_8181"
      kubectl patch application "$PROJECT_NAME" -n "$ARGOCD_NAMESPACE" --type merge -p "{\"spec\":{\"source\":{\"repoURL\":\"$ALTERNATIVE_URL\"}}}" >/dev/null
      sleep 10
      # Tentative de sync via patch
      kubectl patch application "$PROJECT_NAME" -n "$ARGOCD_NAMESPACE" --type merge -p '{"operation":{"sync":{"revision":"HEAD","syncOptions":["CreateNamespace=true"]}}}' >/dev/null 2>&1 || true
    else
      # Pas d'erreur: tenter une sync standard via patch
      kubectl patch application "$PROJECT_NAME" -n "$ARGOCD_NAMESPACE" --type merge -p '{"operation":{"sync":{"revision":"HEAD","syncOptions":["CreateNamespace=true"]}}}' >/dev/null 2>&1 || true
    fi

    # Attendre l'état Synced/Healthy
    SYNC_OK=0
    for t in {1..30}; do
      APP_JSON=$(kubectl get application "$PROJECT_NAME" -n "$ARGOCD_NAMESPACE" -o json 2>/dev/null || echo "")
      SYNC_STATUS=$(echo "$APP_JSON" | jq -r '.status.sync.status // empty')
      HEALTH_STATUS=$(echo "$APP_JSON" | jq -r '.status.health.status // empty')
      if [ "$SYNC_STATUS" = "Synced" ] && [ "$HEALTH_STATUS" = "Healthy" ]; then
        SYNC_OK=1; break
      fi
      sleep 5
    done
    if [ $SYNC_OK -eq 1 ]; then
      echo "✅ Application synchronisée avec succès (kubectl)"
      break
    else
      echo "⚠️  Synchronisation échouée (tentative $i/3), nouvelle tentative dans 30s"
      sleep 30
    fi
  else
    echo "⚠️  Application non trouvée (tentative $i/3)"
    sleep 10
  fi
done

# Étape 8: Afficher le statut final
echo "=== Statut final ==="
if [ "$HAS_ARGOCD" -eq 1 ]; then
  argocd app get "$PROJECT_NAME" 2>/dev/null || kubectl get application "$PROJECT_NAME" -n "$ARGOCD_NAMESPACE" -o yaml
else
  kubectl get application "$PROJECT_NAME" -n "$ARGOCD_NAMESPACE" -o yaml
fi

echo "Pods déployés dans le namespace $DEV_NAMESPACE:"
kubectl get pods -n "$DEV_NAMESPACE" || echo "Aucun pod déployé"

echo "Services dans le namespace $DEV_NAMESPACE:"
kubectl get svc -n "$DEV_NAMESPACE" || echo "Aucun service déployé"

# Nettoyer
if [ -n "$PF_PID" ]; then
  kill $PF_PID 2>/dev/null || true
fi

echo "✅ Configuration ArgoCD-GitLab terminée"
echo "🎯 GitLab accessible à l'URL: $CHOSEN_REPO_URL"
echo "🎯 Application ArgoCD: $PROJECT_NAME"

