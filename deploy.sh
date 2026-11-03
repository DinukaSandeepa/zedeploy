#!/usr/bin/env bash
# /usr/local/bin/nextjs-deploy
#
# Installed root-owned, outside the deploy-owned app dir, so neither the deploy
# user nor the app (which runs as deploy) can modify the script the SSH key runs.
#
# Forced command for the GitHub Actions SSH key (see README). Reads a .tar.gz of
# the Next.js standalone build from stdin, then:
#   1. unpacks it into releases/<timestamp>
#   2. copies hashed static assets into a shared dir served by Nginx
#   3. atomically flips the "current" symlink
#   4. rolling-restarts each instance: drain in Nginx -> restart -> wait for health -> undrain
#   5. rolls back automatically if any instance fails its health check
#
# A broken build therefore never takes down both instances: the loop stops at the
# first unhealthy one, which stays marked "down" while the other keeps serving.

set -Eeuo pipefail

APP_DIR=/var/www/myapp
RELEASES_DIR="$APP_DIR/releases"
CURRENT="$APP_DIR/current"
STATIC_DIR="$APP_DIR/shared/static"
PORTS=(3000 3001)
KEEP_RELEASES=5
HEALTH_PATH=/api/health
HEALTH_TIMEOUT=60   # seconds to wait for a restarted instance to become healthy
DRAIN_WAIT=2        # seconds to let in-flight requests finish after draining

log() { echo "[deploy $(date +%T)] $*" >&2; }

# Only one deploy at a time
exec 9>"$APP_DIR/.deploy.lock"
flock -n 9 || { log "another deploy is already running"; exit 1; }

# Mark one port as down in Nginx (or none), via the root-owned helper.
# The deploy user cannot write Nginx config itself.
write_upstream() {
  sudo /usr/local/sbin/nextjs-drain "${1:-none}" || { log "nginx upstream update failed"; return 1; }
}

wait_healthy() {
  local port="$1" deadline=$((SECONDS + HEALTH_TIMEOUT))
  until curl -fsS --max-time 3 "http://127.0.0.1:${port}${HEALTH_PATH}" >/dev/null 2>&1; do
    if (( SECONDS >= deadline )); then return 1; fi
    sleep 1
  done
}

# Drain -> restart -> health check -> undrain. On failure the port stays "down" in Nginx.
restart_port() {
  local port="$1"
  log "draining :$port"
  write_upstream "$port" || return 1
  sleep "$DRAIN_WAIT"
  log "restarting nextjs@$port"
  sudo /usr/bin/systemctl restart "nextjs@$port"
  if wait_healthy "$port"; then
    write_upstream "" || return 1
    log ":$port healthy and back in rotation"
    return 0
  fi
  log ":$port FAILED health check"
  return 1
}

flip_symlink() {
  ln -sfn "$1" "$APP_DIR/current.tmp"
  mv -Tf "$APP_DIR/current.tmp" "$CURRENT"   # rename(2): atomic
}

rollback() {
  if [[ -z "$PREV" || ! -d "$PREV" ]]; then
    log "no previous release to roll back to"
    return 1
  fi
  log "rolling back to $PREV"
  flip_symlink "$PREV"
  local p
  for p in "${TOUCHED[@]}"; do
    restart_port "$p" || log "WARNING: :$p still unhealthy after rollback, check journalctl -u nextjs@$p"
  done
}

# ---- 1. unpack the new release -------------------------------------------------
PREV="$(readlink -f "$CURRENT" 2>/dev/null || true)"
RELEASE_ID="$(date +%Y%m%d%H%M%S)"
NEW="$RELEASES_DIR/$RELEASE_ID"
mkdir -p "$NEW" "$STATIC_DIR"

log "unpacking release $RELEASE_ID"
tar -xzf - -C "$NEW"

if [[ ! -f "$NEW/server.js" ]]; then
  log "artifact has no server.js, aborting"
  rm -rf "$NEW"
  exit 1
fi

# ---- 2. shared static assets (hashed filenames, safe to merge) -----------------
if [[ -d "$NEW/.next/static" ]]; then
  cp -rf "$NEW/.next/static/." "$STATIC_DIR/"
fi

# ---- 3. atomic switch ----------------------------------------------------------
flip_symlink "$NEW"
log "current -> $NEW (previous: ${PREV:-none})"

# ---- 4. rolling restart --------------------------------------------------------
TOUCHED=()
for port in "${PORTS[@]}"; do
  TOUCHED+=("$port")
  if ! restart_port "$port"; then
    rollback || true
    log "deploy FAILED and was rolled back"
    exit 1
  fi
  sleep 2
done

# ---- 5. cleanup ----------------------------------------------------------------
ls -1dt "$RELEASES_DIR"/*/ | tail -n +$((KEEP_RELEASES + 1)) | xargs -r rm -rf
find "$STATIC_DIR" -type f -mtime +30 -delete 2>/dev/null || true

log "deploy OK: $RELEASE_ID"
