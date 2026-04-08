Perform a security assessment of the codebase to identify vulnerabilities and risks.

Load the following expertise before starting:

- [security-hardening](../../../skills/security-hardening/SKILL.md)
- [Reviewer Agent](../../../agents/reviewer.md)

## Steps

1. Scan for common vulnerability patterns (Injection, XSS, insecure storage).
2. Check authentication and authorization logic.
3. Audit dependency security for known CVEs.
4. Verify configuration security (secrets, headers).
5. Report findings with CVSS-based severity and remediation steps.

## Rules

- Follow the [security-hardening](../../../skills/security-hardening/SKILL.md) standards.
- Never log or display sensitive data (passwords, tokens).
- Verify every user-controlled input for proper validation/sanitization.
