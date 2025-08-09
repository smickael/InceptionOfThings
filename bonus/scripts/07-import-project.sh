#!/bin/bash
set -e

echo "=== Importing project into GitLab ==="


GITLAB_NAMESPACE="gitlab"
GITLAB_HOST="gitlab.42.fr"
PROJECT_NAME="hbenyah-playground"
GITHUB_REPO="https://github.com/Policonickolu/hbenyah-playground.git"

GITLAB_API_URL="http://$GITLAB_HOST/api/v4"


 # Check if PAT is set, otherwise read from /tmp/gitlab_pat.txt
if [ -z "$GITLAB_PAT" ]; then
  PAT_FILE="/tmp/gitlab_pat.txt"
  if [ -f "$PAT_FILE" ]; then
    GITLAB_PAT=$(cat "$PAT_FILE" | tr -d '\n')
    if [ -z "$GITLAB_PAT" ]; then
  echo "❌ Empty PAT in $PAT_FILE. Aborting."
      exit 1
    fi
  echo "🔑 PAT loaded from $PAT_FILE."
  else
  echo "❌ GITLAB_PAT not set and file $PAT_FILE not found. Aborting."
    exit 1
  fi
fi

# Now construct the remote URL without the PAT
GITLAB_REPO_URL="http://$GITLAB_HOST/root/$PROJECT_NAME.git"

 # Check if GitLab API is reachable
API_PING=$(curl -s -o /dev/null -w "%{http_code}" --header "PRIVATE-TOKEN: $GITLAB_PAT" "$GITLAB_API_URL/projects")
if [ "$API_PING" != "200" ]; then
  echo "❌ Unable to access GitLab API ($GITLAB_API_URL/projects), code: $API_PING"
  exit 1
fi

 # Check if project exists
SEARCH_BODY=$(curl -s --header "PRIVATE-TOKEN: $GITLAB_PAT" "$GITLAB_API_URL/projects?search=$PROJECT_NAME")
PROJECT_ID=$(echo "$SEARCH_BODY" | jq -r ".[] | select(.name == \"$PROJECT_NAME\") | .id // empty")

if [ -n "$PROJECT_ID" ] && [ "$PROJECT_ID" != "null" ]; then
  echo "Deleting existing GitLab project with ID: $PROJECT_ID..."
  DELETE_RESPONSE=$(curl -s -w "\n%{http_code}" --request DELETE "$GITLAB_API_URL/projects/$PROJECT_ID" --header "PRIVATE-TOKEN: $GITLAB_PAT")
  DELETE_BODY=$(echo "$DELETE_RESPONSE" | head -n -1)
  DELETE_CODE=$(echo "$DELETE_RESPONSE" | tail -n1)
  if [ "$DELETE_CODE" != "202" ]; then
  echo "❌ HTTP error while deleting project: $DELETE_CODE"
    echo "$DELETE_BODY"
    exit 1
  fi
  echo "✅ GitLab project deleted."
  # Refresh project ID after deletion
  SEARCH_BODY=""
  PROJECT_ID=""
fi

echo "Creating GitLab project..."
CREATE_RESPONSE=$(curl -s -w "\n%{http_code}" --request POST "$GITLAB_API_URL/projects" \
    --header "PRIVATE-TOKEN: $GITLAB_PAT" \
    --form "name=$PROJECT_NAME" \
    --form "path=$PROJECT_NAME" \
    --form "namespace_id=1" \
    --form "visibility=public" \
    --form "default_branch_protection=0")
CREATE_BODY=$(echo "$CREATE_RESPONSE" | head -n -1)
CREATE_CODE=$(echo "$CREATE_RESPONSE" | tail -n1)
if [ "$CREATE_CODE" != "201" ]; then
  echo "❌ HTTP error while creating project: $CREATE_CODE"
  echo "$CREATE_BODY"
  exit 1
fi
PROJECT_ID=$(echo "$CREATE_BODY" | jq -r '.id')
if [ -z "$PROJECT_ID" ] || [ "$PROJECT_ID" = "null" ]; then
  echo "❌ Error creating GitLab project (no ID)"
  echo "$CREATE_BODY"
  exit 1
fi
echo "✅ GitLab project created with ID: $PROJECT_ID"

echo "⏳ Triggering GitHub repo import by GitLab..."
IMPORT_TRIGGER=$(curl -s -w "\n%{http_code}" --request POST \
  --header "PRIVATE-TOKEN: $GITLAB_PAT" \
  --form "import_url=$GITHUB_REPO" \
  "$GITLAB_API_URL/projects/$PROJECT_ID/repository/import")
IMPORT_BODY=$(echo "$IMPORT_TRIGGER" | head -n -1)
IMPORT_CODE=$(echo "$IMPORT_TRIGGER" | tail -n1)

 # If 404, try alternative endpoint /projects/:id/import (different GitLab versions)
if [ "$IMPORT_CODE" = "404" ]; then
  ALT_TRIGGER=$(curl -s -w "\n%{http_code}" --request POST \
    --header "PRIVATE-TOKEN: $GITLAB_PAT" \
    --form "import_url=$GITHUB_REPO" \
    "$GITLAB_API_URL/projects/$PROJECT_ID/import")
  IMPORT_BODY=$(echo "$ALT_TRIGGER" | head -n -1)
  IMPORT_CODE=$(echo "$ALT_TRIGGER" | tail -n1)
fi

if [ "$IMPORT_CODE" = "200" ] || [ "$IMPORT_CODE" = "201" ] || [ "$IMPORT_CODE" = "202" ]; then
  # Wait for server-side import to finish
  MAX_TRIES=60
  SLEEP_SECS=2
  TRY=1
  while [ $TRY -le $MAX_TRIES ]; do
    STATUS_JSON=$(curl -s --header "PRIVATE-TOKEN: $GITLAB_PAT" "$GITLAB_API_URL/projects/$PROJECT_ID")
    IMPORT_STATUS=$(echo "$STATUS_JSON" | jq -r '.import_status // "none"')
    if [ "$IMPORT_STATUS" = "finished" ]; then
      DEFAULT_BRANCH=$(echo "$STATUS_JSON" | jq -r '.default_branch // empty')
  echo "✅ Import finished. Default branch: ${DEFAULT_BRANCH:-unknown}"
  echo "✅ Project successfully imported into GitLab"
      exit 0
    elif [ "$IMPORT_STATUS" = "failed" ]; then
  echo "❌ Import failed."
      echo "$STATUS_JSON"
      exit 1
    fi
  echo "… status: $IMPORT_STATUS (attempt $TRY/$MAX_TRIES)"
    TRY=$((TRY+1))
    sleep "$SLEEP_SECS"
  done
  echo "❌ Timeout waiting for project import."
  exit 1
fi

 # Fallback: import via API (commit all files)
echo "⚠️  Server-side import unavailable (HTTP $IMPORT_CODE). Fallback via API (commit)."
TMP_DIR="/tmp/${PROJECT_NAME}-import"
rm -rf "$TMP_DIR"
echo "Cloning GitHub repo..."
if ! git clone --quiet "$GITHUB_REPO" "$TMP_DIR"; then
  echo "❌ Failed to clone GitHub repo ($GITHUB_REPO)"
  exit 1
fi

echo "Preparing initial commit via API..."
ACTIONS='[]'
while IFS= read -r -d '' f; do
  rel="${f#$TMP_DIR/}"
  # Encode in base64; Linux/macOS compatible
  if base64 -w0 < /dev/null >/dev/null 2>&1; then
    b64=$(base64 -w0 "$f")
  else
    b64=$(base64 "$f" | tr -d '\n')
  fi
  ACTIONS=$(echo "$ACTIONS" | jq --arg path "$rel" --arg content "$b64" '. + [{action:"create", file_path:$path, content:$content, encoding:"base64"}]')
done < <(find "$TMP_DIR" -type f -not -path '*/.git/*' -print0)

 # Build and send the commit
PAYLOAD=$(jq -n --arg branch "main" --arg msg "Initial import from GitHub ($GITHUB_REPO)" --argjson actions "$ACTIONS" '{branch:$branch, commit_message:$msg, actions:$actions}')
COMMIT_RESPONSE=$(curl -s -w "\n%{http_code}" --request POST \
  --header "PRIVATE-TOKEN: $GITLAB_PAT" \
  --header "Content-Type: application/json" \
  --data "$PAYLOAD" \
  "$GITLAB_API_URL/projects/$PROJECT_ID/repository/commits")
COMMIT_BODY=$(echo "$COMMIT_RESPONSE" | head -n -1)
COMMIT_CODE=$(echo "$COMMIT_RESPONSE" | tail -n1)

rm -rf "$TMP_DIR"

if [ "$COMMIT_CODE" != "201" ]; then
  echo "❌ Failed initial commit (HTTP $COMMIT_CODE)"
  echo "$COMMIT_BODY"
  exit 1
fi

# Set default branch to main (just in case)
PUT_RESP=$(curl -s -w "\n%{http_code}" --request PUT \
  --header "PRIVATE-TOKEN: $GITLAB_PAT" \
  --data "default_branch=main" \
  "$GITLAB_API_URL/projects/$PROJECT_ID")
PUT_CODE=$(echo "$PUT_RESP" | tail -n1)

if [ "$PUT_CODE" != "200" ]; then
  echo "⚠️  Unable to set default branch to main (HTTP $PUT_CODE)"
fi

echo "✅ Project successfully imported into GitLab (via API)"
exit 0
