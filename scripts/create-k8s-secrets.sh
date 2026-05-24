#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# create-k8s-secrets.sh
# Run this ONCE to create Kubernetes secrets that Flux/GitOps can't store in Git.
#
# What this creates:
#   1. regcred          — GHCR pull credentials (lets k8s pull your private image)
#   2. jarvis-secrets   — API keys and Signal config (sensitive env vars)
#   3. jarvis-ssh-key   — SSH private key for Proxmox access
#   4. flux-github-auth — GitHub PAT for Flux image automation write-back
#
# Run: bash scripts/create-k8s-secrets.sh
# Requires: .env file at docker/agent/.env  +  kubectl pointing at your cluster
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

ENV_FILE="$(dirname "$0")/../docker/agent/.env"
SSH_KEY="${SSH_KEY_PATH:-$HOME/.ssh/identity.rsa}"
NAMESPACE="homeservarr"

# ── Preflight checks ──────────────────────────────────────────────────────────
if [[ ! -f "$ENV_FILE" ]]; then
  echo "ERROR: $ENV_FILE not found. Copy docker/agent/.env.example → docker/agent/.env and fill it in."
  exit 1
fi

if ! kubectl get namespace "$NAMESPACE" &>/dev/null; then
  echo "Creating namespace $NAMESPACE..."
  kubectl create namespace "$NAMESPACE"
fi

# ── Load .env ─────────────────────────────────────────────────────────────────
# shellcheck disable=SC1090
source <(grep -v '^#' "$ENV_FILE" | grep '=')

# ── 1. GHCR pull secret ───────────────────────────────────────────────────────
# Kubernetes needs this to pull images from ghcr.io.
# Your GITHUB_PAT must have: read:packages permission.
echo ""
echo "1/4 — GHCR pull secret (regcred)"
read -rp "     GitHub username (majorrabbid): " GITHUB_USER
GITHUB_USER="${GITHUB_USER:-majorrabbid}"
read -rsp "    GitHub Personal Access Token (needs read:packages): " GITHUB_PAT
echo ""

kubectl create secret docker-registry regcred \
  --docker-server=ghcr.io \
  --docker-username="$GITHUB_USER" \
  --docker-password="$GITHUB_PAT" \
  --namespace="$NAMESPACE" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "     ✓ regcred created"

# ── 2. Jarvis app secrets ─────────────────────────────────────────────────────
echo ""
echo "2/4 — Jarvis app secrets (jarvis-secrets)"

: "${ANTHROPIC_API_KEY:?ANTHROPIC_API_KEY not set in .env}"
: "${JARVIS_NUMBER:?JARVIS_NUMBER not set in .env}"
: "${ALLOWED_SENDERS:?ALLOWED_SENDERS not set in .env}"

kubectl create secret generic jarvis-secrets \
  --from-literal=ANTHROPIC_API_KEY="$ANTHROPIC_API_KEY" \
  --from-literal=JARVIS_NUMBER="$JARVIS_NUMBER" \
  --from-literal=ALLOWED_SENDERS="$ALLOWED_SENDERS" \
  --from-literal=OVERSEERR_API_KEY="${OVERSEERR_API_KEY:-}" \
  --namespace="$NAMESPACE" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "     ✓ jarvis-secrets created"

# ── 3. SSH key secret ─────────────────────────────────────────────────────────
echo ""
echo "3/4 — SSH key secret (jarvis-ssh-key)"

if [[ ! -f "$SSH_KEY" ]]; then
  echo "ERROR: SSH key not found at $SSH_KEY"
  echo "Set SSH_KEY_PATH env var to the correct path, e.g.:"
  echo "  SSH_KEY_PATH=~/.ssh/id_ed25519 bash scripts/create-k8s-secrets.sh"
  exit 1
fi

kubectl create secret generic jarvis-ssh-key \
  --from-file=identity.rsa="$SSH_KEY" \
  --namespace="$NAMESPACE" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "     ✓ jarvis-ssh-key created (key: $SSH_KEY)"

# ── 4. Flux GitHub write-back token ──────────────────────────────────────────
# Flux image automation needs to WRITE to your repo (to update deployment.yaml).
# Create a GitHub PAT with: repo (or contents:write) permission.
echo ""
echo "4/4 — Flux GitHub write-back token (flux-github-auth)"
echo "     This allows Flux to commit image tag updates back to GitHub."
echo "     Create a PAT at: https://github.com/settings/tokens/new"
echo "     Required scope: repo → contents (write)"
read -rsp "    GitHub PAT for Flux write-back: " FLUX_PAT
echo ""

kubectl create secret generic flux-github-auth \
  --from-literal=username="majorrabbid" \
  --from-literal=password="$FLUX_PAT" \
  --namespace=flux-system \
  --dry-run=client -o yaml | kubectl apply -f -

echo "     ✓ flux-github-auth created"

# ── Update GitRepository to use auth for write-back ──────────────────────────
kubectl patch gitrepository homeservarr-repo -n flux-system \
  --type='merge' \
  -p '{"spec":{"secretRef":{"name":"flux-github-auth"}}}' 2>/dev/null || true

echo ""
echo "All secrets created. Flux will reconcile within 5 minutes."
echo "Watch progress: kubectl get pods -n homeservarr -w"
