#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# run_pipeline.sh
#
# Top-level entry point: runs the full VAPT pipeline against the local
# OWASP Juice Shop target (setup -> recon -> scan -> sqli -> jwt -> idor ->
# exposure -> report) by delegating to `make all`.
#
#   ./run_pipeline.sh            # run everything
#   ./run_pipeline.sh clean      # tear down + clear results
#   ./run_pipeline.sh recon      # run a single phase (any Makefile target)
# ---------------------------------------------------------------------------
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

TARGET="${1:-all}"
echo "[INFO] vapt-pipeline: running 'make ${TARGET}'"
make "${TARGET}"
