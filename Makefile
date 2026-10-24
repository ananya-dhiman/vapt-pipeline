# ---------------------------------------------------------------------------
# Makefile — VAPT pipeline orchestration against OWASP Juice Shop.
#
# Each target maps 1:1 to a phase script under scripts/, so phases can be
# run independently (e.g. `make sqli`) or chained together (`make all`).
# ---------------------------------------------------------------------------
SHELL := /bin/bash
SCRIPTS := scripts

.PHONY: setup recon scan sqli jwt idor exposure report all clean

setup:       ## Phase 1: start Juice Shop in Docker, wait for it to be healthy
	@bash $(SCRIPTS)/00_setup.sh

recon: setup ## Phase 2: Nmap scan + app fingerprint
	@bash $(SCRIPTS)/01_recon.sh

scan: setup  ## Phase 3: OWASP ZAP baseline/full scan
	@bash $(SCRIPTS)/02_zap_scan.sh

sqli: setup  ## Phase 4: auth-bypass PoC + sqlmap confirmation
	@bash $(SCRIPTS)/03_sqli.sh

jwt: setup   ## Phase 5: capture + decode session JWT (jwt_tool)
	@bash $(SCRIPTS)/04_jwt.sh

idor: setup  ## Phase 6: IDOR probe on /rest/basket/{id} and /rest/user/whoami
	@bash $(SCRIPTS)/05_idor.sh

exposure: setup ## Phase 7: unauthenticated /ftp/ disclosure
	@bash $(SCRIPTS)/06_exposure.sh

report:      ## Phase 8: aggregate all phase outputs into results/report.md
	@python3 $(SCRIPTS)/07_report.py

all: setup recon scan sqli jwt idor exposure report ## Run the full pipeline in order

clean:       ## Tear down the target container and clear results
	@echo "[INFO] Stopping and removing Juice Shop container (if present)..."
	-@docker rm -f $$(grep -m1 '^JUICE_SHOP_CONTAINER=' config/target.env | cut -d'"' -f2) 2>/dev/null
	@echo "[INFO] Clearing results/ (keeping .gitkeep placeholders)..."
	@find results -type f ! -name '.gitkeep' -delete
	@echo "[ OK ] Clean complete."
