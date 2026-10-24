#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# scripts/00_setup.sh — Phase 1: Target setup
#
# Spins up OWASP Juice Shop via Docker and waits until it answers HTTP
# requests on TARGET_URL. Idempotent: re-running it reuses/restarts the
# existing container instead of erroring out.
# ---------------------------------------------------------------------------
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

require docker "Install Docker: https://docs.docker.com/get-docker/"

log "Checking for an existing '${JUICE_SHOP_CONTAINER}' container..."

if docker ps -a --format '{{.Names}}' | grep -qx "${JUICE_SHOP_CONTAINER}"; then
  if docker ps --format '{{.Names}}' | grep -qx "${JUICE_SHOP_CONTAINER}"; then
    ok "Container '${JUICE_SHOP_CONTAINER}' already running."
  else
    log "Container exists but is stopped; starting it..."
    docker start "${JUICE_SHOP_CONTAINER}" >/dev/null
  fi
else
  log "Pulling ${JUICE_SHOP_IMAGE}:${JUICE_SHOP_IMAGE_TAG} and starting container..."
  docker run -d \
    --name "${JUICE_SHOP_CONTAINER}" \
    -p "${TARGET_PORT}:3000" \
    "${JUICE_SHOP_IMAGE}:${JUICE_SHOP_IMAGE_TAG}" >/dev/null
fi

log "Waiting for ${TARGET_URL} to become healthy (timeout 90s)..."
if wait_for_http "${TARGET_URL}" 90; then
  ok "Juice Shop is up at ${TARGET_URL}"
else
  err "Juice Shop did not become healthy within 90s. Check 'docker logs ${JUICE_SHOP_CONTAINER}'."
  exit 1
fi
