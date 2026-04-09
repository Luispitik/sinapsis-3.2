---
name: cso-audit
version: 1.0.0
description: |
  Chief Security Officer audit. OWASP Top 10 + STRIDE threat modeling + supply chain +
  LLM security, with stack-aware checks for Next.js, Supabase, Prisma, Stripe, and more.
  Two modes: daily (confidence gate 8/10, zero-noise) and comprehensive (gate 2/10, deep scan).
  Inspired by gstack /cso (garrytan).
tags: [security, audit, owasp, stride, supply-chain, llm-security, cso]
triggers: ["security audit", "OWASP", "threat model", "CSO review", "pentest", "vulnerability scan"]
allowed-tools:
  - Bash
  - Read
  - Grep
  - Glob
  - Write
  - Agent
  - WebSearch
  - AskUserQuestion
---

# /cso-audit — Security Audit OWASP + STRIDE + Supply Chain

## Step 0: Mode resolution

Ask the user or detect from invocation:

- `/cso-audit` or `/cso-audit --daily` → **Daily mode** (confidence gate: 8/10, zero-noise)
- `/cso-audit --comprehensive` → **Comprehensive mode** (confidence gate: 2/10, deep scan)

Default: daily.

## Step 1: Stack detection

```bash
# Detect project tech
[ -f "package.json" ] && echo "NODE_PROJECT=true" || echo "NODE_PROJECT=false"
[ -f "next.config.ts" ] || [ -f "next.config.js" ] || [ -f "next.config.mjs" ] && echo "NEXTJS=true" || echo "NEXTJS=false"
[ -f "prisma/schema.prisma" ] && echo "PRISMA=true" || echo "PRISMA=false"
[ -d "supabase" ] || grep -q "supabase" package.json 2>/dev/null && echo "SUPABASE=true" || echo "SUPABASE=false"
grep -q "stripe" package.json 2>/dev/null && echo "STRIPE=true" || echo "STRIPE=false"
[ -f "vercel.json" ] && echo "VERCEL=true" || echo "VERCEL=false"
```

## Step 2: Secrets archaeology

Scan for exposed secrets in code AND git history:

```bash
# Current codebase (exclude node_modules, .env files)
grep -rn "SUPABASE_SERVICE_ROLE\|sk_live\|sk_test\|OPENAI_API_KEY\|ANTHROPIC_API_KEY\|password\s*=" --include="*.ts" --include="*.tsx" --include="*.js" --include="*.json" . 2>/dev/null | grep -v node_modules | grep -v ".env" | head -20

# Git history (last 50 commits)
git log --all -p -50 --diff-filter=A -- "*.env" "*.env.*" 2>/dev/null | head -20

# Check .gitignore coverage
[ -f ".gitignore" ] && grep -q ".env" .gitignore && echo "GITIGNORE_ENV=covered" || echo "GITIGNORE_ENV=MISSING"
```

**Severity:** CRITICAL for any hardcoded secret in source code.

## Step 3: Dependency supply chain

```bash
# Known vulnerabilities
npm audit --json 2>/dev/null | head -50

# Outdated with security implications
npm outdated 2>/dev/null | head -20

# Check for suspicious scripts in dependencies
grep -r "postinstall\|preinstall" node_modules/*/package.json 2>/dev/null | grep -v "node-gyp\|esbuild\|sharp\|prisma" | head -10
```

**Daily mode:** Only report HIGH and CRITICAL npm audit findings.
**Comprehensive mode:** Report all findings including MODERATE.

## Step 4: OWASP Top 10 (stack-adapted)

### A01 — Broken Access Control
- API routes WITHOUT auth middleware or verification
- Supabase queries WITHOUT RLS context
- Middleware protecting sensitive routes

```bash
# API routes without auth (adapt pattern to your framework)
for f in $(find . -path "*/api/*" -name "*.ts" -o -name "*.js" 2>/dev/null | grep -v node_modules); do
  grep -L "verifyAuth\|getSession\|auth()\|getUser\|requireAuth" "$f" 2>/dev/null
done
```

### A02 — Cryptographic Failures
- Secrets in client-side code (`NEXT_PUBLIC_` prefix with sensitive data)
- JWT tokens in localStorage (should be httpOnly cookies)
- Weak hashing algorithms

### A03 — Injection
- SQL injection: raw queries with string concatenation
- XSS: `dangerouslySetInnerHTML`, unescaped user content
- Shell injection: `exec()`, `spawn()` with user-controlled input
- Prompt injection: user input in AI SDK calls without sanitization

### A04 — Insecure Design
- Server Components fetching data without auth check
- API routes without rate limiting
- File uploads without type/size validation
- Missing CSRF protection on state-changing operations

### A05 — Security Misconfiguration
```bash
# Check security headers
[ -f "vercel.json" ] && cat vercel.json | grep -A2 "Strict-Transport\|X-Content-Type\|X-Frame-Options\|X-XSS" || echo "MISSING_SECURITY_HEADERS"

# Check CORS configuration
grep -rn "Access-Control-Allow-Origin\|cors" --include="*.ts" --include="*.js" . 2>/dev/null | grep -v node_modules | head -10

# Source maps in production
grep -rn "productionBrowserSourceMaps" next.config.* 2>/dev/null
```

### A06 — Vulnerable and Outdated Components
- Already covered by Step 3 (npm audit)

### A07 — Identification and Authentication Failures
- Auth gate points (register page, OAuth callback, middleware)
- Session management: refresh token handling
- Password policies (if custom auth)

### A08 — Software and Data Integrity Failures
- Webhook signature validation (Stripe HMAC, etc.)
- CI/CD pipeline security (GitHub Actions permissions)

### A09 — Security Logging and Monitoring Failures
- No secrets in logs
- Audit trail for sensitive operations
- Error messages that leak implementation details

### A10 — Server-Side Request Forgery (SSRF)
- `fetch()` in Server Components with user-controlled URLs
- Redirect handling with user-controlled destinations

## Step 5: STRIDE Threat Model

For each component in the architecture, evaluate:

| Threat | What to check |
|--------|---------------|
| **Spoofing** | JWT validation, auth implementation, session tokens |
| **Tampering** | RLS policies, webhook signatures, input validation |
| **Repudiation** | Event logging, audit trail for admin actions |
| **Info Disclosure** | Error messages, source maps, .env exposure |
| **Denial of Service** | Rate limiting, input size limits, query complexity |
| **Elevation of Privilege** | Role-based access, admin route protection, RLS bypass |

## Step 6: LLM/AI Security (if AI SDK detected)

```bash
grep -rn "streamText\|generateObject\|generateText\|anthropic\|openai" --include="*.ts" --include="*.tsx" . 2>/dev/null | grep -v node_modules | head -20
```

If found:
- **Prompt injection:** Is user input sanitized before reaching AI prompts?
- **Output trust boundary:** Is AI output validated before DB writes or rendering?
- **API key exposure:** Are AI API keys in `.env.local` only (not `NEXT_PUBLIC_`)?
- **Rate limiting:** Do AI endpoints have per-user rate limits?
- **Cost protection:** Is there max token/request limiting?

## Step 7: Compile findings

For each finding:
```json
{
  "id": "CSO-NNN",
  "phase": "owasp-a01|stride-spoofing|supply-chain|...",
  "severity": "CRITICAL|HIGH|MEDIUM|LOW|INFO",
  "confidence": 1-10,
  "title": "Short description",
  "description": "Detailed explanation",
  "evidence": "File:line or command output",
  "remediation": "What to fix and how",
  "effort": "minutes|hours|days"
}
```

**Apply confidence gate:**
- Daily mode: only include findings with confidence >= 8
- Comprehensive mode: include findings with confidence >= 2

## Step 8: Generate report

Output structured report:

```markdown
# Security Audit Report — [Project Name]
**Mode:** Daily/Comprehensive
**Date:** YYYY-MM-DD
**Auditor:** CSO Audit v1.0

## Executive Summary
- Total findings: N
- Critical: N | High: N | Medium: N | Low: N
- Security Posture Score: X/10

## Findings by Category
### OWASP Top 10
[findings grouped by A01-A10]

### STRIDE Threats
[findings grouped by threat type]

### Supply Chain
[npm audit results]

### LLM Security
[AI-specific findings]

## Remediation Priority
1. [CRITICAL] Fix immediately: ...
2. [HIGH] Fix this week: ...
3. [MEDIUM] Fix this sprint: ...

## Next Steps
- Schedule comprehensive audit if this was daily
- Review and apply remediations
- Re-run audit after fixes to verify
```

**Security Posture Score:**
```
score = 10 - (critical * 3 + high * 1.5 + medium * 0.5 + low * 0.1)
score = max(0, min(10, score))
```

## Important Rules

1. **Never execute exploits.** This is an audit, not a pentest. Read code, don't attack it.
2. **Evidence required.** Every finding must cite file:line or command output.
3. **No false positives in daily mode.** The 8/10 confidence gate exists to prevent noise.
4. **Actionable remediations.** Every finding must include a specific fix, not just "fix this."
5. **Respect the stack.** Checks adapt to the detected stack. Don't flag patterns that are safe in the project's framework.
