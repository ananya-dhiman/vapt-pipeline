#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# scripts/02_zap_scan.sh — Phase 3: Automated scan (OWASP ZAP)
#
# Runs the ZAP baseline (or full) scan via the official Docker image
# against the target and exports HTML + JSON reports. Uses
# --network=host style access by targeting host.docker.internal so the
# ZAP container can reach the Juice Shop container's published port.
# ---------------------------------------------------------------------------
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

require docker "Install Docker: https://docs.docker.com/get-docker/"

OUT_DIR="${VAPT_ROOT}/${RESULTS_DIR}/zap"
mkdir -p "$OUT_DIR"

# From inside the ZAP container, reach the host-published Juice Shop port.
# host.docker.internal works on Docker Desktop (Win/Mac); on native Linux
# Docker we fall back to --add-host to map it to the host gateway.
ZAP_TARGET_URL="http://host.docker.internal:${TARGET_PORT}"

SCRIPT="zap-baseline.py"
if [[ "${ZAP_SCAN_MODE}" == "full" ]]; then
  SCRIPT="zap-full-scan.py"
fi

log "Running ZAP (${ZAP_SCAN_MODE}) scan against ${ZAP_TARGET_URL} using ${ZAP_IMAGE}..."
log "(ZAP baseline/full scans intentionally return a non-zero exit code when"
log " alerts are found — the pipeline treats that as success, not failure.)"

docker run --rm \
  --add-host=host.docker.internal:host-gateway \
  -v "${OUT_DIR}:/zap/wrk/:rw" \
  "${ZAP_IMAGE}" "${SCRIPT}" \
  -t "${ZAP_TARGET_URL}" \
  -r zap_report.html \
  -J zap_report.json \
  -w zap_report.md \
  | tee "$(logfile 02_zap_scan)"

ok "ZAP reports saved to ${OUT_DIR}/ (zap_report.html / .json / .md)"
