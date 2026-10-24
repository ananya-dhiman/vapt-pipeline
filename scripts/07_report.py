#!/usr/bin/env python3
# ---------------------------------------------------------------------------
# scripts/07_report.py — Phase 8: Reporting
#
# Walks results/<phase>/ for every tool's raw output and assembles a single
# consolidated results/report.md, including a findings-to-OWASP-Top-10/CWE
# summary table. Pure stdlib (no extra deps) so it runs anywhere python3 is
# available.
# ---------------------------------------------------------------------------
import datetime
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RESULTS = os.path.join(ROOT, "results")


def read(path, limit=4000):
    """Read a text file, truncated for report readability."""
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as fh:
            data = fh.read()
    except FileNotFoundError:
        return None
    if len(data) > limit:
        data = data[:limit] + f"\n... [truncated, see {os.path.relpath(path, ROOT)}]"
    return data


def read_json(path):
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as fh:
            return json.load(fh)
    except (FileNotFoundError, json.JSONDecodeError):
        return None


def section(title, body):
    body = body if body is not None else "_No output found for this phase. Run the corresponding `make` target._"
    return f"## {title}\n\n```\n{body}\n```\n" if body and not body.startswith("_") else f"## {title}\n\n{body}\n"


FINDINGS = [
    {
        "finding": "SQL Injection (login auth-bypass)",
        "owasp": "A03:2021 - Injection",
        "cwe": "CWE-89",
        "evidence": "results/sqli/auth_bypass_response.json, results/sqli/sqlmap_output.txt",
        "remediation": "Use parameterised queries / an ORM with bound parameters for all SQL; never concatenate user input into queries.",
    },
    {
        "finding": "Broken Access Control (IDOR on /rest/basket/{id})",
        "owasp": "A01:2021 - Broken Access Control",
        "cwe": "CWE-639",
        "evidence": "results/idor/basket_idor_summary.txt, results/idor/whoami.json",
        "remediation": "Enforce server-side authorisation: verify the authenticated user owns the requested object before returning it.",
    },
    {
        "finding": "Sensitive Data Exposure (/ftp/ directory listing)",
        "owasp": "A05:2021 - Security Misconfiguration",
        "cwe": "CWE-548",
        "evidence": "results/exposure/ftp_directory_listing.html, results/exposure/acquisitions.md",
        "remediation": "Disable directory listing / autoindex on the web server, and do not expose internal file shares via the public web root.",
    },
    {
        "finding": "Weak JWT Handling (role=admin claim trusted from client)",
        "owasp": "A02:2021 - Cryptographic Failures",
        "cwe": "CWE-347",
        "evidence": "results/jwt/decoded_token.txt",
        "remediation": "Sign JWTs with a strong, server-held secret/key, validate the signature and claims server-side on every request, and never trust client-decoded claims for authorization decisions.",
    },
    {
        "finding": "Security Misconfiguration (ZAP-reported missing headers / verbose config)",
        "owasp": "A05:2021 - Security Misconfiguration",
        "cwe": "CWE-693",
        "evidence": "results/zap/zap_report.html, results/zap/zap_report.json",
        "remediation": "Apply security headers (CSP, X-Content-Type-Options, HSTS), lock down CORS, and remove default/verbose configuration before deployment.",
    },
    {
        "finding": "Information Disclosure (verbose errors / version banners from recon)",
        "owasp": "A05:2021 - Security Misconfiguration",
        "cwe": "CWE-200",
        "evidence": "results/recon/nmap_full.txt, results/recon/fingerprint.txt",
        "remediation": "Strip verbose banners/stack traces from responses, run services with minimal disclosed version info, and handle errors generically in production.",
    },
]


def findings_table():
    header = "| # | Finding | OWASP Top 10 | CWE | Evidence | Remediation |\n"
    header += "|---|---------|--------------|-----|----------|--------------|\n"
    rows = []
    for i, f in enumerate(FINDINGS, start=1):
        rows.append(
            f"| {i} | {f['finding']} | {f['owasp']} | {f['cwe']} | `{f['evidence']}` | {f['remediation']} |"
        )
    return header + "\n".join(rows) + "\n"


def main():
    now = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    out_path = os.path.join(RESULTS, "report.md")

    parts = []
    parts.append(f"# VAPT Pipeline Report — OWASP Juice Shop\n")
    parts.append(f"_Generated: {now}_\n")
    parts.append(
        "**Course:** Vulnerability Assessment & Penetration Testing, Sem VII, KJSSE  \n"
        "**Authors:** Ananya Dhiman (16010123041), Anoushka Nelson (16010123049)  \n"
        "**Target:** OWASP Juice Shop, run locally at http://localhost:3000 "
        "(intentionally vulnerable training application; legal, purpose-built target).\n"
    )

    parts.append("## Findings Summary\n\n" + findings_table())

    parts.append(section("Phase 2 — Recon (Nmap)", read(os.path.join(RESULTS, "recon", "nmap_full.txt"))))
    parts.append(section("Phase 2 — Fingerprint", read(os.path.join(RESULTS, "recon", "fingerprint.txt"))))

    zap_json = read_json(os.path.join(RESULTS, "zap", "zap_report.json"))
    if zap_json is not None:
        n_alerts = sum(len(site.get("alerts", [])) for site in zap_json.get("site", []))
        zap_summary = f"ZAP reported {n_alerts} distinct alert type(s). Full report: results/zap/zap_report.html"
    else:
        zap_summary = None
    parts.append(section("Phase 3 — OWASP ZAP Scan", zap_summary))

    parts.append(section("Phase 4 — SQLi Auth-Bypass Response", read(os.path.join(RESULTS, "sqli", "auth_bypass_response.pretty.json"))))
    parts.append(section("Phase 4 — sqlmap Output", read(os.path.join(RESULTS, "sqli", "sqlmap_output.txt"))))

    parts.append(section("Phase 5 — Decoded JWT", read(os.path.join(RESULTS, "jwt", "decoded_token.txt"))))

    parts.append(section("Phase 6 — IDOR (/rest/user/whoami)", read(os.path.join(RESULTS, "idor", "whoami.json"))))
    parts.append(section("Phase 6 — IDOR Basket Probe Summary", read(os.path.join(RESULTS, "idor", "basket_idor_summary.txt"))))

    parts.append(section("Phase 7 — Sensitive Data Exposure", read(os.path.join(RESULTS, "exposure", "evidence_summary.txt"))))
    acquisitions = read(os.path.join(RESULTS, "exposure", "acquisitions.md"))
    if acquisitions:
        parts.append(section("Phase 7 — acquisitions.md Contents", acquisitions))

    with open(out_path, "w", encoding="utf-8") as fh:
        fh.write("\n".join(parts))

    print(f"[ OK ] Report written to {os.path.relpath(out_path, ROOT)}")


if __name__ == "__main__":
    sys.exit(main())
