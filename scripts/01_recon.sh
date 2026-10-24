#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# scripts/01_recon.sh — Phase 2: Recon
#
# Nmap service/script scan against the target host, plus a quick HTTP
# fingerprint (headers, title, X-Powered-By) of the running app. Raw
# output is saved for the report.
# ---------------------------------------------------------------------------
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

require nmap "apt install nmap / brew install nmap"
require curl "apt install curl / brew install curl"

OUT_DIR="${VAPT_ROOT}/${RESULTS_DIR}/recon"
mkdir -p "$OUT_DIR"

log "Running Nmap service/script scan against ${TARGET_HOST} (all ports, this can take a while)..."
# -sV: service/version detection, -sC: default scripts, -p-: all 65535 ports.
nmap -sV -sC -p- "${TARGET_HOST}" \
  -oN "${OUT_DIR}/nmap_full.txt" \
  -oX "${OUT_DIR}/nmap_full.xml" \
  | tee "$(logfile 01_recon)"

ok "Nmap output saved to ${OUT_DIR}/nmap_full.txt"

log "Fingerprinting the web application on ${TARGET_URL}..."
{
  echo "=== HTTP response headers ==="
  curl -fsS -D - -o /dev/null "${TARGET_URL}/"
  echo
  echo "=== Page title ==="
  curl -fsS "${TARGET_URL}/" | grep -o '<title>[^<]*</title>' || echo "(title not found)"
  echo
  echo "=== /server-status / technology hints (X-Powered-By, server, etc. already above) ==="
} > "${OUT_DIR}/fingerprint.txt" 2>&1

ok "Fingerprint saved to ${OUT_DIR}/fingerprint.txt"
