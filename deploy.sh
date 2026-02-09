#!/usr/bin/env bash
#
# Deploy frontend-ex to aya as a systemd-managed Phoenix release.
#
# This script syncs the repo to the server, builds a release on the server,
# promotes it into a versioned `releases/<id>/` directory, flips `current`,
# and restarts the systemd service.
#
# Usage:
#   FX_DEPLOY_SERVER=aya FX_DEPLOY_PATH=/mnt/sepolia/frontend-ex ./deploy.sh
#   ./deploy.sh --dry-run
#
set -euo pipefail

SERVER="${FX_DEPLOY_SERVER:-aya}"
REMOTE_PATH="${FX_DEPLOY_PATH:-/mnt/sepolia/frontend-ex}"
SERVICE_NAME="${FX_SERVICE_NAME:-frontend-ex}"
KEEP_RELEASES="${FX_KEEP_RELEASES:-5}"

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

log() { echo "[$(date +%H:%M:%S)] $1"; }
run() {
  if [ "$DRY_RUN" = true ]; then
    log "[DRY RUN] $*"
    return 0
  fi
  eval "$@"
}

if [ "$SKIP_SYNC" = false ]; then
  log "Syncing repo to $SERVER:$REMOTE_PATH..."
  run "rsync -avz --delete \
    --exclude _build/ \
    --exclude deps/ \
    --exclude .git/ \
    --exclude .jj/ \
    --exclude tmp/ \
    \"$LOCAL_PATH/\" \"$SERVER:$REMOTE_PATH/\""
else
  log "Skipping rsync (requested)"
fi

if [ "$SKIP_BUILD" = false ]; then
  log "Building release on server..."
  build_cmd="cd \"$REMOTE_PATH\" && MIX_ENV=prod mix deps.get --only prod && MIX_ENV=prod mix compile && MIX_ENV=prod mix release --overwrite"
  run "ssh \"$SERVER\" \"$build_cmd\""

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
  run "ssh \"$SERVER\" \"$promote_cmd\""

  log "Pruning old releases (keep $KEEP_RELEASES)..."
  prune_cmd="set -euo pipefail
cd \"$REMOTE_PATH\"
mkdir -p releases
keep=$KEEP_RELEASES
if [ \"\$keep\" -gt 0 ]; then
  ls -1dt releases/* 2>/dev/null | tail -n +\$((keep + 1)) | xargs -r rm -rf --
fi"
  run "ssh \"$SERVER\" \"$prune_cmd\""
else
  log "Skipping build/promotion (requested)"
fi

if [ "$SKIP_RESTART" = false ]; then
  log "Restarting systemd service: $SERVICE_NAME"
  run "ssh \"$SERVER\" \"systemctl restart \\\"$SERVICE_NAME\\\"\""
else
  log "Skipping service restart (requested)"
fi

log "[OK] Deploy complete."

