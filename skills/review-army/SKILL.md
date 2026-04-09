---
name: review-army
version: 1.0.0
description: |
  Code review with 5 parallel specialists (security, nextjs, supabase, performance, testing).
  Fix-First workflow: auto-fix mechanical issues, only ASK on critical findings.
  PR Quality Score 0-10 with trending.
  Inspired by gstack /review (garrytan), adapted for Next.js + Supabase + Prisma + Stripe stacks.
tags: [review, code-review, pr, security, quality, pre-landing]
triggers: ["review", "code review", "pre-landing review", "check my diff", "review my PR"]
allowed-tools:
  - Bash
  - Read
  - Edit
  - Write
  - Grep
  - Glob
  - Agent
  - AskUserQuestion
---

# /review-army — Code Review with Parallel Specialists

## Step 0: Detect base branch and diff

```bash
BASE=$(git remote show origin 2>/dev/null | grep 'HEAD branch' | awk '{print $NF}')
[ -z "$BASE" ] && BASE="main"
CURRENT=$(git branch --show-current 2>/dev/null)
echo "BRANCH: $CURRENT → base: $BASE"
```

If on the base branch or no diff: output "Nothing to review — you're on the base branch." and STOP.

```bash
git fetch origin "$BASE" --quiet 2>/dev/null
git diff "origin/$BASE" --stat
```

If no diff, STOP.

## Step 1: Get the full diff

```bash
git diff "origin/$BASE"
```

Read the full diff. Count lines changed, files changed, and classify the scope.

## Step 1.5: Stack detection from CLAUDE.md

Before dispatching specialists, read the project's CLAUDE.md (if it exists) to detect the actual framework and stack. This overrides file-extension-based assumptions.

```bash
cat CLAUDE.md 2>/dev/null | head -50
```

Key detection rules:
- If CLAUDE.md says "Vite" or "React SPA" → **skip nextjs specialist** even if .tsx/.jsx files changed
- If CLAUDE.md says "Next.js" → enable nextjs specialist
- If CLAUDE.md says "no Supabase" → skip supabase specialist
- If CLAUDE.md says "no Stripe" → skip security checks for Stripe webhooks
- If CLAUDE.md says "plain JS" → skip TypeScript-specific checks

## Step 2: Scope classification

Based on the diff AND the stack detected in Step 1.5, classify which specialists to dispatch:

| Specialist | Dispatch when |
|-----------|---------------|
| **security** | diff touches `route.ts`, `api/`, `auth`, `middleware`, `.env`, `supabase`, or >100 lines backend |
| **nextjs** | diff touches `.tsx`, `.jsx`, `page.`, `layout.`, `route.` AND stack is Next.js |
| **supabase** | diff touches `.prisma`, `.sql`, `supabase`, `migration`, `rls` |
| **performance** | diff touches `fetch`, `cache`, `query`, `bundle`, or >200 lines |
| **testing** | ALWAYS dispatches if diff >50 lines |

## Step 3: Critical pass (you, the orchestrator)

Apply these CRITICAL checks against the full diff:

### SQL & Data Safety
- Raw SQL without parameterized queries
- Missing WHERE clause on UPDATE/DELETE
- Schema changes without migration

### Race Conditions
- Shared mutable state without locking
- Optimistic updates without retry
- Read-modify-write without transaction

### Auth & RLS
- Supabase tables without RLS policies
- API routes without JWT validation
- Missing auth check in Server Components that fetch user data

### Shell/Prompt Injection
- User input in shell commands without escaping
- User input concatenated into AI prompts without sanitization
- `dangerouslySetInnerHTML` with user content

### Enum Completeness
- New enum value added but switch/case not updated everywhere
- Read OUTSIDE the diff with Grep to verify all references handle new value

For each finding, output JSON:
```json
{"severity":"CRITICAL|INFORMATIONAL","confidence":1-10,"path":"file","line":0,"category":"category","summary":"description","fix":"recommended fix","fingerprint":"path:line:category"}
```

## Step 4: Dispatch specialists in parallel

Launch ALL qualifying specialists simultaneously using the Agent tool. Each specialist receives:
- The full diff (via `git diff origin/<base>`)
- Their specific checklist (below)
- Relevant instincts from Sinapsis (if available)

### Security specialist checklist
- OWASP Top 10 adapted: injection, broken auth, sensitive data exposure, broken access control, security misconfiguration, XSS, insecure deserialization, known vulnerabilities, insufficient logging
- Supabase RLS verification: every table mutation must have RLS
- JWT validation: every API route with sensitive data must verify auth
- Webhook HMAC: every webhook endpoint must verify signature
- Secret exposure: no secrets in client-side code, no secrets in logs

### Next.js specialist checklist
- Server Components: no `useState`/`useEffect` in server components
- Async params: `params` and `searchParams` are Promise in Next.js 15+, must await
- Cache strategy: appropriate use of cache directives
- Metadata: `generateMetadata` for SEO on page routes
- Image optimization: `next/image` instead of `<img>`

### Supabase specialist checklist
- RLS policies on ALL tables (no exceptions)
- Auth gate points: register page, OAuth callback, middleware
- Migration files for schema changes
- Prisma client regeneration after schema changes
- JSON parse/stringify for InputJsonValue (Prisma gotcha)

### Performance specialist checklist
- N+1 queries (especially with Prisma `include`)
- Missing indexes on frequently queried columns
- Unbounded queries without `take`/`limit`
- Client-side data fetching that should be server-side
- Bundle size: unnecessary imports, missing tree-shaking

### Testing specialist checklist
- New functions without test coverage
- Changed behavior without updated tests
- Edge cases: null, empty, boundary values
- Error paths: what happens when external services fail
- Integration points: API contracts between modules

Each specialist outputs findings in the same JSON format as Step 3.

## Step 4.5: CLAUDE.md staleness check

Cross-reference what the diff touches against what CLAUDE.md describes:

1. **Stack drift**: Does the code use tech not mentioned in CLAUDE.md?
2. **Stale patterns**: Does CLAUDE.md reference patterns that no longer exist in the code?
3. **Missing sections**: Does CLAUDE.md lack critical sections for this project type?

If CLAUDE.md doesn't exist at all, flag it as HIGH — the review army needs stack context for accurate specialist dispatch.

## Step 5: Merge and deduplicate findings

Collect all findings from critical pass + specialists.

**Dedup by fingerprint** (`path:line:category`):
- If same fingerprint from multiple specialists: keep highest confidence, tag as "MULTI-SPECIALIST CONFIRMED", boost confidence by +1 (cap 10)
- Group remaining findings by severity

**Compute PR Quality Score:**
```
quality_score = max(0, 10 - (critical_count * 2 + informational_count * 0.5))
```

## Step 6: Fix-First workflow

### 6a: Classify each finding
- **AUTO-FIX**: import ordering, missing types, formatting, obvious mechanical fixes, unused imports
- **ASK**: logic changes, security decisions, architectural choices, anything with confidence <7

### 6b: Apply AUTO-FIX items
For each auto-fixed item:
```
[AUTO-FIXED] [file:line] Problem -> what you did
```

### 6c: Batch-ask about ASK items
Present all ASK items in ONE prompt:
```
I auto-fixed N issues. M need your input:

1. [CRITICAL] path:line — Problem
   Fix: recommended fix
   -> A) Fix  B) Skip

RECOMMENDATION: Fix #1 because...
```

### 6d: Apply user-approved fixes

## Step 7: Summary output

```
## Review Summary
- Branch: feature/X -> main
- Files changed: N
- Quality Score: X/10
- Critical findings: N (M fixed, K skipped)
- Informational findings: N (M auto-fixed)
- Specialists dispatched: security, nextjs, supabase
```

## Important Rules

1. **Verify before claiming**: if you claim something is safe, cite the specific line. Never say "probably tested" — verify or flag as unknown.
2. **No false confidence**: if unsure, report confidence honestly. An observed pattern verified in code is 8-9. An inference is 4-5.
3. **Respect suppressions**: if a comment says `// eslint-disable` or `// @ts-ignore` with explanation, don't flag it.
4. **Search before recommending**: verify recommended patterns are current for the framework version in use.
5. **Minimal fixes**: each fix should be the smallest change that resolves the issue.
