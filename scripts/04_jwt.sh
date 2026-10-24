#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# scripts/04_jwt.sh — Phase 5: JWT analysis
#
# Captures the session JWT issued on login (reusing the auth-bypass login
# from phase 4 if available, otherwise logging in fresh) and decodes it
# with jwt_tool (ticarpi) to show the role=admin claim riding in a token
# the client was never meant to be able to forge/trust blindly.
# ---------------------------------------------------------------------------
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

require curl "apt install curl / brew install curl"
require jq "apt install jq / brew install jq"

OUT_DIR="${VAPT_ROOT}/${RESULTS_DIR}/jwt"
mkdir -p "$OUT_DIR"

TOKEN_FILE="${OUT_DIR}/token.txt"

if [[ -s "$TOKEN_FILE" ]]; then
  log "Reusing token captured during the SQLi phase."
  token="$(cat "$TOKEN_FILE")"
else
  log "No cached token found — logging in with the auth-bypass payload..."
  token="$(login_and_capture_token)" || { err "Could not obtain a token."; exit 1; }
fi

if ! JWT_TOOL_CMD="$(resolve_jwt_tool)"; then
  warn "Falling back to a manual base64 decode (jwt_tool unavailable)."
  IFS='.' read -r header payload _sig <<< "$token"
  {
    echo "=== JWT header ==="
    echo "$header" | base64 -d 2>/dev/null | jq '.' || echo "$header" | base64 -d 2>/dev/null
    echo
    echo "=== JWT payload ==="
    echo "$payload" | base64 -d 2>/dev/null | jq '.' || echo "$payload" | base64 -d 2>/dev/null
  } > "${OUT_DIR}/decoded_token.txt" 2>&1
else
  log "Decoding token with jwt_tool (${JWT_TOOL_CMD})..."
  # shellcheck disable=SC2086
  ${JWT_TOOL_CMD} "$token" 2>&1 | tee "${OUT_DIR}/decoded_token.txt" | tee "$(logfile 04_jwt)"
fi

ok "Decoded token saved to ${OUT_DIR}/decoded_token.txt"

role="$(IFS='.' read -r _h payload _s <<< "$token"; echo "$payload" | base64 -d 2>/dev/null | jq -r '.data.role // empty' 2>/dev/null)"
if [[ -n "$role" ]]; then
  ok "Decoded role claim: '${role}' — confirms the admin-bypass login carries elevated privileges."
fi
