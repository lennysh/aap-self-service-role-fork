#!/usr/bin/env bash
# Quick-start wrapper for the AAP Self-Service Portal Ansible role.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

VARS_FILE="${1:-var_files/aap26-portal.yml}"
TAGS="${TAGS:-}"
EXTRA_ARGS=()

usage() {
  cat <<'EOF'
Install the AAP Self-Service Portal on OpenShift.

Usage:
  ./install-portal.sh [vars-file]

Examples:
  ./install-portal.sh                          # uses var_files/aap26-portal.yml
  ./install-portal.sh var_files/aap27-portal.yml
  TAGS=preflight ./install-portal.sh           # run preflight checks only
  TAGS=helm ./install-portal.sh                # re-run Helm deploy only

Before running:
  1. oc login <cluster-api-url>
  2. cp var_files/portal.yml.example var_files/aap26-portal.yml
  3. Edit the vars file (AAP host, password, namespace)
  4. Extract plugins OR set download_plugins: true in the vars file

Dependencies (once per machine):
  ansible-galaxy collection install -r collections/requirements.yml
  pip install -r python-requirements.txt
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ ! -f "$VARS_FILE" ]]; then
  echo "Vars file not found: $VARS_FILE" >&2
  echo "Copy var_files/portal.yml.example and customize it first." >&2
  exit 1
fi

for cmd in oc helm ansible-playbook; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Required command not found: $cmd" >&2
    exit 1
  fi
done

if ! oc whoami >/dev/null 2>&1; then
  echo "Not logged in to OpenShift. Run: oc login <api-url>" >&2
  exit 1
fi

echo "==> Using vars file: $VARS_FILE"
echo "==> OpenShift server: $(oc whoami --show-server)"

PLAYBOOK_ARGS=(-e "@${VARS_FILE}")
if [[ -n "$TAGS" ]]; then
  PLAYBOOK_ARGS+=(--tags "$TAGS")
  echo "==> Running tags: $TAGS"
else
  echo "==> Running full install (set TAGS=preflight to validate only)"
fi

ansible-playbook deploy-aap-selfservice.yml "${PLAYBOOK_ARGS[@]}" "${EXTRA_ARGS[@]}"

if [[ -z "$TAGS" || "$TAGS" == *"helm"* || "$TAGS" == *"update_oauth"* ]]; then
  ROUTE="$(oc get route -n "$(grep '^openshift_namespace:' "$VARS_FILE" | awk '{print $2}')" \
    -l app.kubernetes.io/instance=self-service \
    -o jsonpath='{.items[0].spec.host}' 2>/dev/null || true)"
  if [[ -n "$ROUTE" ]]; then
    echo ""
    echo "Portal URL: https://${ROUTE}"
  fi
fi
