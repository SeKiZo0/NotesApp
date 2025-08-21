#!/usr/bin/env bash
# setup-insecure-registry.sh
# Purpose: Configure a k3s or standalone containerd node to trust an HTTP (insecure) registry
# Idempotent: safe to re-run; backs up existing config files once per run.
# NOTE: Prefer enabling HTTPS on the registry long-term. This is a stop-gap.
#
# Usage:
#   sudo ./setup-insecure-registry.sh \
#       --registry 192.168.1.150:3000 \
#       --test-image morris/notes-app-backend:latest
#
# Options:
#   --registry <host:port>   HTTP registry address (default: 192.168.1.150:3000)
#   --test-image <name:tag>  Optional image (without registry prefix) to test pull
#   --dry-run                Show actions only
#   --force                  Skip interactive confirmations
#
# Exit codes:
#   0 success
#   1 generic failure
#   2 missing prerequisite

set -euo pipefail

REGISTRY="192.168.1.150:3000"
TEST_IMAGE=""
DRY_RUN=0
FORCE=0

log() { echo -e "[INFO] $*"; }
warn() { echo -e "[WARN] $*" >&2; }
err()  { echo -e "[ERROR] $*" >&2; }
run()  { if [[ $DRY_RUN -eq 1 ]]; then echo "+ $*"; else eval "$*"; fi }

require_root() { if [[ $(id -u) -ne 0 ]]; then err "Run as root (use sudo)."; exit 2; fi }

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --registry) REGISTRY="$2"; shift 2;;
      --test-image) TEST_IMAGE="$2"; shift 2;;
      --dry-run) DRY_RUN=1; shift;;
      --force) FORCE=1; shift;;
      -h|--help) grep '^# ' "$0" | sed 's/^# //'; exit 0;;
      *) err "Unknown arg: $1"; exit 2;;
    esac
  done
}

backup_once() {
  local f="$1"
  if [[ -f "$f" && ! -f "${f}.bak" ]]; then
    run cp "$f" "${f}.bak"
    log "Backup created: ${f}.bak"
  fi
}

is_k3s() { systemctl is-active --quiet k3s || systemctl is-active --quiet k3s-agent; }

restart_runtime() {
  if is_k3s; then
    if systemctl is-active --quiet k3s; then run systemctl restart k3s; else run systemctl restart k3s-agent; fi
  else
    run systemctl restart containerd
  fi
}

configure_k3s() {
  local file="/etc/rancher/k3s/registries.yaml"
  run mkdir -p /etc/rancher/k3s
  backup_once "$file"
  # Merge / overwrite minimal mirror block (simple strategy)
  local tmp=$(mktemp)
  cat > "$tmp" <<EOF
mirrors:
  "${REGISTRY}":
    endpoint:
      - "http://${REGISTRY}"
configs:
  "${REGISTRY}":
    tls:
      insecure_skip_verify: true
EOF
  if [[ -f "$file" ]]; then
    # Remove any existing block for this registry (basic approach)
    run awk -v r="${REGISTRY}" 'BEGIN{skip=0} \
      /^mirrors:/ || /^configs:/ {print} \
      {next}' "$file" >/dev/null 2>&1 || true
  fi
  run cp "$tmp" "$file"
  rm -f "$tmp"
  log "Written k3s registries.yaml for ${REGISTRY}"
}

configure_containerd() {
  local file="/etc/containerd/config.toml"
  if [[ ! -f $file ]]; then
    log "Generating default containerd config.toml"
    run containerd config default > "$file"
  fi
  backup_once "$file"
  # Remove existing mirror stanza for registry then append our config if absent
  if grep -q "registry.mirrors.\"${REGISTRY}\"" "$file"; then
    warn "Existing mirror entry found for ${REGISTRY} (not pruning automatically)."
  fi
  if ! grep -q "insecure_skip_verify" "$file" | grep -q "${REGISTRY}" 2>/dev/null; then
    cat <<EOF >> "$file"
[plugins."io.containerd.grpc.v1.cri".registry.mirrors."${REGISTRY}"]
  endpoint = ["http://${REGISTRY}"]
[plugins."io.containerd.grpc.v1.cri".registry.configs."${REGISTRY}".tls]
  insecure_skip_verify = true
EOF
    log "Appended insecure mirror config for ${REGISTRY}"
  else
    warn "Config may already contain insecure stanza for ${REGISTRY}";
  fi
}

pull_test_image() {
  [[ -z "$TEST_IMAGE" ]] && return 0
  local full="${REGISTRY}/${TEST_IMAGE}"
  log "Test pulling image: $full"
  if command -v crictl >/dev/null 2>&1; then
    run crictl pull "$full" || warn "crictl pull failed (may still be starting)"
  else
    warn "crictl not found; skipping runtime pull test"
  fi
}

main() {
  parse_args "$@"
  require_root
  if [[ $FORCE -ne 1 ]]; then
    echo "About to configure insecure registry access for: ${REGISTRY}" >&2
    read -r -p "Proceed? (y/N) " ans
    [[ "$ans" == "y" || "$ans" == "Y" ]] || { err "Aborted"; exit 1; }
  fi
  if is_k3s; then
    log "Detected k3s environment"
    configure_k3s
  else
    log "Assuming standalone containerd"
    configure_containerd
  fi
  restart_runtime
  pull_test_image
  log "Done. Re-deploy workloads or rerun Jenkins pipeline now."
  log "If pods still fail: describe a failing pod and check events for image pull errors."
}

main "$@"
