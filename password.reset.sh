#!/bin/bash
set -e

NAMESPACE="argocd"

echo "í´„ Resetting ArgoCD admin password properly..."

# Step 1: Generate a new password
NEW_PASSWORD=$(openssl rand -base64 16)
echo "í²¡ New admin password will be: $NEW_PASSWORD"

# Step 2: Generate bcrypt hash
if ! command -v htpasswd &> /dev/null; then
    echo "âŒ htpasswd command not found. Install apache2-utils or httpd-tools."
    exit 1
fi
HASH=$(htpasswd -bnBC 10 "" "$NEW_PASSWORD" | tr -d ':\n')

# Step 3: Delete old secret if exists
kubectl delete secret -n $NAMESPACE argocd-secret --ignore-not-found

# Step 4: Recreate secret with correct bcrypt hash
kubectl create secret generic argocd-secret -n $NAMESPACE \
  --from-literal=admin.password="$HASH" \
  --from-literal=server.secretkey=$(openssl rand -base64 32) \
  --from-literal=server.secret=$(openssl rand -base64 32)

# Step 5: Remove old metadata if exists
kubectl patch secret -n $NAMESPACE argocd-secret --type='json' \
  -p='[{"op": "remove", "path": "/data/admin.passwordMtime"}]' 2>/dev/null || true

# Step 6: Restart ArgoCD server
kubectl rollout restart deployment -n $NAMESPACE argocd-server

echo "âœ… ArgoCD admin password has been reset. Use this password to login:"
echo "   Username: admin"
echo "   Password: $NEW_PASSWORD"

