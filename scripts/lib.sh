#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# scripts/lib.sh
#
# Shared helpers sourced by every phase script: config loading, logging,
# dependency checks with install hints, and a couple of small HTTP/JWT
# utilities reused across phases (login, token storage).
#
# Usage: source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
# ---------------------------------------------------------------------------
set -uo pipefail

# Resolve repo root regardless of where the script is invoked from.
VAPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# shellcheck source=../config/target.env
source "${VAPT_ROOT}/config/target.env"

mkdir -p "${VAPT_ROOT}/${LOG_DIR}"

# --- logging ----------------------------------------------------------------
log()  { echo -e "[\033[1;34mINFO\033[0m] $*"; }
ok()   { echo -e "[\033[1;32m OK \033[0m] $*"; }
warn() { echo -e "[\033[1;33mWARN\033[0m] $*"; }
err()  { echo -e "[\033[1;31mFAIL\033[0m] $*" >&2; }

# Log to both stdout and a phase-specific logfile.
# usage: logfile <phase-name>
logfile() {
  echo "${VAPT_ROOT}/${LOG_DIR}/$1.log"
}

# --- dependency checks --------------------------------------------------
# require <command> <install-hint>
# Fails fast with a clear message if a tool is missing.
require() {
  local cmd="$1" hint="$2"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    err "Required tool '${cmd}' not found on PATH."
    err "  Install hint: ${hint}"
    exit 1
  fi
}

# --- jwt_tool discovery ---------------------------------------------------
# jwt_tool (ticarpi) is usually cloned rather than packaged. Resolve a
# callable command, preferring a PATH binary, then a local clone, else fail
# with install instructions.
resolve_jwt_tool() {
  if command -v jwt_tool >/dev/null 2>&1; then
    echo "jwt_tool"
    return 0
  fi
  if command -v jwt_tool.py >/dev/null 2>&1; then
    echo "jwt_tool.py"
    return 0
  fi
  if [[ -f "${VAPT_ROOT}/tools/jwt_tool/jwt_tool.py" ]]; then
    echo "python3 ${VAPT_ROOT}/tools/jwt_tool/jwt_tool.py"
    return 0
  fi
  err "jwt_tool (ticarpi) not found."
  err "  Install hint: git clone https://github.com/ticarpi/jwt_tool \"${VAPT_ROOT}/tools/jwt_tool\" && pip3 install -r \"${VAPT_ROOT}/tools/jwt_tool/requirements.txt\""
  return 1
}

# --- HTTP helpers -----------------------------------------------------------
# wait_for_http <url> <timeout_seconds>
wait_for_http() {
  local url="$1" timeout="${2:-60}" waited=0
  while ! curl -fsS -o /dev/null "$url" 2>/dev/null; do
    sleep 2
    waited=$((waited + 2))
    if (( waited >= timeout )); then
      return 1
    fi
  done
  return 0
}

# login_and_capture_token: POST the auth-bypass payload to the Juice Shop
# login endpoint and store the raw response + extracted bearer token so
# downstream phases (jwt, idor) can reuse the same session.
# Writes:
#   results/sqli/auth_bypass_response.json
#   results/jwt/token.txt
login_and_capture_token() {
  require curl "apt install curl / brew install curl"
  require jq "apt install jq / brew install jq"

  local out_json="${VAPT_ROOT}/${RESULTS_DIR}/sqli/auth_bypass_response.json"
  local out_token="${VAPT_ROOT}/${RESULTS_DIR}/jwt/token.txt"
  mkdir -p "$(dirname "$out_json")" "$(dirname "$out_token")"

  curl -fsS -X POST "${LOGIN_ENDPOINT}" \
    -H "Content-Type: application/json" \
    -d "{\"email\": \"${SQLI_BYPASS_EMAIL}\", \"password\": \"${SQLI_BYPASS_PASSWORD}\"}" \
    -o "$out_json"

  local token
  token="$(jq -r '.authentication.token // empty' "$out_json")"
  if [[ -z "$token" ]]; then
    err "Login did not return a token - see ${out_json}"
    return 1
  fi
  echo -n "$token" > "$out_token"
  echo "$token"
}
