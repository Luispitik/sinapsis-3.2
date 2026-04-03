# /evolve -- Instinct Evolution Pipeline

> Analyze mature instincts and cluster them into actionable outputs:
> skills, commands, agents, passive rules, or enrichments.

---

## Trigger

Run with `/evolve` or "evolve my instincts".

---

## Process

### Step 1: Gather Candidates

Read `~/.claude/skills/_instincts-index.json` and filter:
- Level `confirmed` or `permanent` (skip drafts)
- Not already evolved (`evolvedTo === null`)
- Sort by level (permanent first), then by domain

### Step 2: Cluster Related Instincts

Group instincts by:
1. **Domain match** -- same domain tag
2. **Tag overlap** -- sharing 2+ tags
3. **Trigger similarity** -- similar trigger conditions
4. **Action complementarity** -- actions that form a workflow

### Step 3: Present Clusters

For each cluster, show:

```
EVOLUTION CANDIDATES

  CLUSTER 1: "API Error Handling" (3 instincts, domain: code-quality)
  ────────────────────────────────────────────────────────────────────
  api-error-appclass  [confirmed] "API errors -> use AppError class"
  catch-with-context  [confirmed] "Catch exceptions -> log with context"
  error-code-response [confirmed] "Return errors -> include error code"

  Combined token impact if evolved:
    [S] Skill    ~800 tokens (new skill in library)
    [C] Command  ~400 tokens (slash command)
    [A] Agent    ~1,200 tokens (autonomous agent)
    [R] Rule     ~100 tokens (passive rule, always active)
    [E] Enrich   +~200 tokens (add to existing "api-builder" skill)
    [P] Promote  ~0 tokens (promote to permanent level)
    [X] Skip     (leave as instincts)

  Choose action: _


  CLUSTER 2: "Deployment Checklist" (3 instincts, domain: deployment)
  ────────────────────────────────────────────────────────────────────
  deploy-run-tests   [permanent]  "Before deploy -> run tests"
  deploy-check-env   [confirmed]  "Before deploy -> check env vars"
  deploy-migrations  [confirmed]  "Before deploy -> verify migrations"

  [S] [C] [A] [R] [E] [P] [X]

  Choose action: _


  SOLO INSTINCTS (not clustered):
  docs-code-examples [confirmed] "When writing docs -> include code examples"
    [P] Promote  [R] Rule  [E] Enrich existing skill  [X] Skip
```

### Step 4: Execute Chosen Action

#### [S] Create Skill

1. Generate a SKILL.md from the clustered instincts
2. Include all trigger/action pairs as instructions
3. Calculate token estimate
4. Save to `~/.claude/skills/_library/{new-skill-id}/SKILL.md`
5. Register in `_catalog.json`
6. Mark source instincts as `evolvedTo: "skill:{skill-id}"`

#### [C] Create Command

1. Generate a command .md file
2. Include the workflow steps from clustered instincts
3. Save to `~/.claude/commands/{command-name}.md`
4. Mark source instincts as `evolvedTo: "command:{command-name}"`

#### [A] Create Agent

1. Generate an agent skill with autonomous capabilities
2. Include decision logic from instinct triggers
3. Add safety guardrails (confirm before destructive actions)
4. Save as a skill with `type: agent` in catalog
5. Mark source instincts as `evolvedTo: "agent:{agent-id}"`

#### [R] Create Passive Rule

1. Generate a rule entry for `_passive-rules.json`
2. Rule fires automatically when trigger matches
3. No user interaction needed
4. Mark source instincts as `evolvedTo: "rule:{rule-id}"`

#### [E] Enrich Existing Skill

1. Identify the target skill
2. Append new knowledge from instincts
3. Update the skill's version (patch bump)
4. Mark source instincts as `evolvedTo: "enriched:{skill-id}"`

#### [P] Promote to Global

1. Move instinct from project scope to global scope
2. Retain full history
3. Update `_instincts-index.json`

### Step 5: Summary

```
EVOLUTION COMPLETE

  Created:
    [S] api-error-handling skill (~800 tokens)
    [C] /deploy-checklist command (~400 tokens)
    [R] "docs-examples" passive rule (~100 tokens)

  Promoted:
    inst_g010 -> global scope

  Skipped: 0

  Token impact: +1,300 tokens to fixed overhead
  New total: ~13,500 tokens (6.8% of budget)
```

### Step 6: Auto-Registration

After generating any new skill or command:
1. Update `_catalog.json` with new entry
2. Update `_projects.json` if project-specific
3. Update `_operator-state.json` if it was a strategic decision
4. Offer to install the new skill immediately
