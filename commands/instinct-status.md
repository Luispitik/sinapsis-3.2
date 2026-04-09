---
name: instinct-status
description: Muestra todos los instincts aprendidos con niveles, dominios, ocurrencias y busqueda cross-project
command: true
---

# /instinct-status

## Trigger

Run with `/instinct-status`, "instinct status", "mis instincts", "que instincts tengo".

**Flags:**
- `/instinct-status` — Default: show global instincts from `_instincts-index.json`
- `/instinct-status --cross-project "query"` — Search instincts across ALL registered projects without promoting

---

## Default Mode

### Step 1: Read Global Instincts

Read `~/.claude/skills/_instincts-index.json`. Parse the `instincts` array.

### Step 2: Group and Sort

Group instincts by `level` (permanent > confirmed > draft), then by `domain`.
Within each level, sort by `occurrences` descending.

### Step 3: Check Confidence Decay

For each instinct, calculate effective level:
- `permanent` — never decays
- `confirmed` with `last_triggered` > 60 days ago — show as `confirmed [DECAYING]`
- `draft` with `last_triggered` > 90 days ago — show as `draft [STALE]`

### Step 4: Display Dashboard

```
══════════════════════════════════════════════════
  INSTINCT STATUS — Sinapsis v4.4
  Total: {N} instincts | {N} permanent | {N} confirmed | {N} draft
══════════════════════════════════════════════════

PERMANENT ({N}):
  [183x] 4-documentos-pack-contractual     [contratos]  manual
  [ 32x] 5-entregables-por-modulo          [formacion]  manual
  [ 28x] castellano-por-defecto            [locale]     manual
  ...

CONFIRMED ({N}):
  [ 15x] supabase-auth-3-gate-points       [supabase]   manual
  [  8x] stripe-customer-id-en-user        [stripe]     manual
  [  3x] next-cache-windows                [nextjs]     learned  [DECAYING]
  ...

DRAFT ({N}):
  [  1x] new-pattern-detected              [general]    learned
  [  0x] stale-unused-instinct             [n8n]        learned  [STALE]
  ...

DOMAINS: contratos(3) formacion(2) supabase(4) stripe(2) nextjs(3) ...
HEALTH: {N} active (triggered <30d) | {N} idle (30-60d) | {N} decaying (>60d)
══════════════════════════════════════════════════
```

---

## Cross-Project Mode (`--cross-project "query"`)

Search instincts across ALL registered projects without promoting them.

### Step 1: Read Project Registry

Read `~/.claude/skills/_projects.json`. Extract all active projects with their `root` paths.

### Step 2: Search Each Project

For each project, check if a project-level instincts file exists:
- `{project_root}/.claude/_instincts-index.json`
- Also check `~/.claude/homunculus/projects/{hash}/instincts/` for legacy format

### Step 3: Match Query

Search instinct `id`, `trigger_pattern`, `inject`, and `domain` fields for the query string (case-insensitive substring match).

### Step 4: Display Cross-Project Results

```
══════════════════════════════════════════════════
  CROSS-PROJECT SEARCH — "{query}"
══════════════════════════════════════════════════

GLOBAL (matched {N}):
  [confirmed] supabase-rls-before-query       [supabase]   15x
    Inject: "Siempre verificar RLS policies antes de..."

PROJECT: norteai-mission-control (matched {N}):
  [draft] supabase-rls-edge-function          [supabase]   2x
    Inject: "Edge Functions no tienen RLS automatico..."

PROJECT: web-salgadoia (matched {N}):
  [confirmed] supabase-rls-public-tables      [supabase]   8x
    Inject: "Tablas publicas necesitan RLS permisivo..."

NO MATCHES in: impulsaflow, test-sherpa, nueva-landing
══════════════════════════════════════════════════

Tip: Use /promote to move a project instinct to global scope.
```

---

## What NOT to Do

- Do not invent instincts that do not exist in the files
- Do not modify any files — this command is read-only
- Do not show raw observations, only processed instincts
- Do not promote instincts automatically — cross-project search is read-only
