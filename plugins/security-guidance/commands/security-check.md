Perform a comprehensive security assessment of the codebase to identify vulnerabilities and risks.

Load the following expertise before starting:

- [security-hardening](../../../skills/security-hardening/SKILL.md)
- [security-auditor](../../../agents/security-auditor.md)
- [Reviewer Agent](../../../agents/reviewer.md)

## Steps

### Phase 1 — Attack Surface Mapping

1. Identify all entry points: API endpoints, file uploads, webhooks, admin panels.
2. Map authentication and authorization boundaries.
3. Trace data flow from user input through processing to storage and output.

### Phase 2 — OWASP Top 10 Audit

Apply the [security-auditor](../../../agents/security-auditor.md) OWASP checklist:

- **A01 Broken Access Control** — IDOR, CORS misconfiguration, JWT validation, admin endpoint exposure.
- **A02 Cryptographic Failures** — TLS version, password hashing algorithm (bcrypt/argon2id only), PII in logs.
- **A03 Injection** — SQL (parameterized queries), NoSQL, command injection, template injection.
- **A04 Insecure Design** — Rate limit bypass, missing account lockout, step-up auth for sensitive ops.
- **A05 Security Misconfiguration** — Security headers (CSP, HSTS, X-Frame-Options), error page exposure.
- **A06 Vulnerable Components** — Run `npm audit` / `pip audit` / `cargo audit`; flag CVEs by CVSS score.
- **A07 Authentication Failures** — Session invalidation on logout, MFA, brute force protection.
- **A08 Data Integrity Failures** — CI/CD untrusted code execution, deserialization allowlists.
- **A09 Logging & Monitoring Failures** — Auth events logged, sensitive data absent from logs.
- **A10 SSRF** — User-provided URLs validated against allowlist, internal network addresses blocked.

### Phase 3 — Secrets Detection

Run or simulate secrets scan:

```bash
# If gitleaks is available
gitleaks detect --source . --report-format json

# Fallback: manual scan patterns
grep -r "password\s*=\s*['\"]" --include="*.py" --include="*.ts" --include="*.js" .
grep -r "api_key\s*=\|API_KEY\s*=" --include="*.env" --include="*.yaml" --include="*.json" .

- Check `.gitignore` excludes `.env`, `*.pem`, `*.key`, credential files.
- Check CI/CD configs for unmasked secrets in env variables.

### Phase 4 — Dependency Audit

```bash
# Node.js
npm audit --json 2>/dev/null | jq '.vulnerabilities | to_entries[] | {name: .key, severity: .value.severity, fixAvailable: .value.fixAvailable}'

# Python
pip audit 2>/dev/null || safety check 2>/dev/null

Flag any Critical or High severity CVEs with remediation path.

### Phase 5 — Report

For each finding output:

[SEVERITY] Location: file:line
Description: what the vulnerability is
Impact: what an attacker could achieve
Remediation: specific fix

Severity levels: **Critical** / **High** / **Medium** / **Low** / **Informational**

## Rules

- Follow [security-hardening](../../../skills/security-hardening/SKILL.md) standards.
- Never log or display sensitive data (passwords, tokens) during the audit.
- Verify every user-controlled input for proper validation/sanitization.
- Report Critical and High findings first; always include remediation steps.
- Communicate sensitive findings through secure channels, not public issue trackers.
