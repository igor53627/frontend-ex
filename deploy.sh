#!/usr/bin/env bash
#
# Deploy frontend-ex to a server as a systemd-managed Phoenix release.
#
# This script syncs the repo to the server, builds a release on the server,
# promotes it into a versioned `releases/<id>/` directory, flips `current`,
# and restarts the systemd service.
#
# Usage:
#   FX_DEPLOY_SERVER=myhost FX_DEPLOY_PATH=/opt/frontend-ex ./deploy.sh
#   ./deploy.sh --dry-run
#
set -euo pipefail

# Source local deploy config if present (gitignored).
# Uses guarded assignments (:=) so explicit env vars take precedence.
if [ -f "$(dirname "$0")/.env.deploy" ]; then
  # shellcheck disable=SC1091
  . "$(dirname "$0")/.env.deploy"
fi

SERVICE_NAME="${FX_SERVICE_NAME:-frontend-ex}"
KEEP_RELEASES="${FX_KEEP_RELEASES:-5}"
# Podman on Ubuntu often requires fully-qualified image names.
BUILD_IMAGE="${FX_BUILD_IMAGE:-docker.io/library/elixir:1.16.3-otp-26}"

LOCAL_PATH="$(cd "$(dirname "$0")" && pwd)"

DRY_RUN=false
SKIP_SYNC=false
SKIP_BUILD=false
SKIP_RESTART=false

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    --skip-sync) SKIP_SYNC=true ;;
    --skip-build) SKIP_BUILD=true ;;
    --skip-restart) SKIP_RESTART=true ;;
    *)
      echo "unknown arg: $arg" >&2
      exit 2
      ;;
  esac
done

# Required env vars — skip validation in dry-run mode so you can preview
# the script flow without a configured target.
if [ "$DRY_RUN" = false ]; then
  : "${FX_DEPLOY_SERVER:?Set FX_DEPLOY_SERVER to your target hostname}"
  : "${FX_DEPLOY_PATH:?Set FX_DEPLOY_PATH to the remote app directory}"
fi
SERVER="${FX_DEPLOY_SERVER:-<server>}"
REMOTE_PATH="${FX_DEPLOY_PATH:-<path>}"

log() { echo "[$(date +%H:%M:%S)] $1"; }
run() {
  if [ "$DRY_RUN" = true ]; then
    log "[DRY RUN] $*"
    return 0
  fi
  "$@"
}

if [ "$SKIP_SYNC" = false ]; then
  log "Syncing repo to $SERVER:$REMOTE_PATH..."
  run rsync -avz --delete \
    --exclude _build/ \
    --exclude deps/ \
    --exclude .git/ \
    --exclude .jj/ \
    --exclude .mix/ \
    --exclude .hex/ \
    --exclude releases/ \
    --exclude current \
    --exclude frontend-ex.env \
    --exclude .env.deploy \
    --exclude tmp/ \
    "$LOCAL_PATH/" "$SERVER:$REMOTE_PATH/"
else
  log "Skipping rsync (requested)"
fi

if [ "$SKIP_BUILD" = false ]; then
  log "Building release on server..."
  build_cmd="set -euo pipefail
cd \"$REMOTE_PATH\"

if command -v mix >/dev/null 2>&1; then
  MIX_ENV=prod mix local.hex --force
  MIX_ENV=prod mix local.rebar --force
  MIX_ENV=prod mix deps.get --only prod
  MIX_ENV=prod mix compile
  MIX_ENV=prod mix release --overwrite
else
  if ! command -v podman >/dev/null 2>&1; then
    echo \"ERROR: neither mix nor podman found on server\" >&2
    exit 1
  fi

  # Build in a container so the host doesn't need Elixir/Erlang installed.
  podman run --rm \
    -v \"$REMOTE_PATH:/app\" \
    -w /app \
    -e MIX_ENV=prod \
    -e MIX_HOME=/app/.mix \
    -e HEX_HOME=/app/.hex \
    \"$BUILD_IMAGE\" \
    sh -lc 'mix local.hex --force && mix local.rebar --force && mix deps.get --only prod && mix compile && mix release --overwrite'
fi"
  run ssh "$SERVER" "$build_cmd"

  log "Promoting release (versioned dir + current symlink)..."
  promote_cmd="set -euo pipefail
cd \"$REMOTE_PATH\"
release_id=\$(date +%Y%m%d%H%M%S)
src=\"_build/prod/rel/frontend_ex\"
dst=\"releases/\$release_id\"
mkdir -p releases
mkdir -p \"\$dst\"
rsync -a --delete \"\$src/\" \"\$dst/\"
ln -sfn \"\$dst\" current
echo \"promoted=\$release_id\""
  run ssh "$SERVER" "$promote_cmd"

  log "Pruning old releases (keep $KEEP_RELEASES)..."
  prune_cmd="set -euo pipefail
cd \"$REMOTE_PATH\"
mkdir -p releases
keep=$KEEP_RELEASES
if [ \"\$keep\" -gt 0 ]; then
  # Releases are named by timestamp (YYYYmmddHHMMSS). Sort by name, not mtime,
  # because rsync -a can preserve directory mtimes and break ls -t ordering.
  old_releases=\$(ls -1 releases 2>/dev/null | sort -r | tail -n +\$((keep + 1)) || true)
  if [ -n \"\$old_releases\" ]; then
    echo \"\$old_releases\" | while read -r rel; do
      [ -n \"\$rel\" ] || continue
      rm -rf -- \"releases/\$rel\"
    done
  fi
fi"
  run ssh "$SERVER" "$prune_cmd"
else
  log "Skipping build/promotion (requested)"
fi

if [ "$SKIP_RESTART" = false ]; then
  log "Restarting systemd service: $SERVICE_NAME"
  run ssh "$SERVER" "systemctl restart \"$SERVICE_NAME\""
else
  log "Skipping service restart (requested)"
fi

log "[OK] Deploy complete."
