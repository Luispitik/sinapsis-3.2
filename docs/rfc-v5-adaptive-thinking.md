# RFC: Adaptive thinking in `/analyze-session`

- **Status:** Draft
- **Author:** Luis Salgado
- **Created:** 2026-04-21
- **Target release:** Sinapsis v5.0
- **Supersedes:** nothing (new feature)
- **Depends on:** Anthropic SDK >= 2026-04, env `ANTHROPIC_API_KEY`

## Context

Sinapsis v4.5 learner is fully deterministic: bash + node regex detectors over
`observations.jsonl`. This is great for the hot path (Stop hook, PreToolUse inject),
but the deep semantic pass — `/analyze-session` — is still only regex-backed.

Claude Opus 4.7 ships with **adaptive thinking** (replacing the old
`budget_tokens` extended-thinking knob) and native interleaved thinking between
tool calls. For offline, on-demand analysis of a session this is a better tool
than hand-written regex: clustering, contradictions across days, natural-language
gotchas that regex can't see.

## Goals

1. `/analyze-session` can optionally call Claude Opus 4.7 with adaptive thinking
   to produce higher-quality instinct proposals.
2. **Zero regression** when the SDK path is disabled: the existing regex pipeline
   remains the default and runs identically.
3. Cost-bounded: one session = at most one API call, with a hard `effort` cap.
4. No leakage of user data (observations are already scrubbed by
   `observe_v3.py` — we rely on that).

## Non-goals

- Moving `_instinct-activator.sh` or `_session-learner.sh` to the SDK. Hot path
  stays bash/node. LLM only in explicit `/analyze-session` flow.
- Auto-apply of LLM proposals. Output still requires human `[A]ccept/[E]dit/[X]`.

## Design

### 1. Opt-in gate

A new env var `SINAPSIS_LLM_ANALYZE=1` enables the SDK branch in
`commands/analyze-session.md`. Default off. Users who do not export it or do not
have `ANTHROPIC_API_KEY` see the current regex-only behaviour with zero network
calls.

### 2. Prompt shape

```python
response = client.messages.create(
    model="claude-opus-4-7",
    max_tokens=4096,
    # Adaptive thinking replaces extended_thinking.budget_tokens (Opus 4.7)
    thinking={"type": "adaptive", "display": "summarized"},
    # Cache the fixed system block — docs for the instinct schema rarely change
    system=[
        {
            "type": "text",
            "text": SINAPSIS_SCHEMA_SYSTEM_PROMPT,  # ~800 tokens, stable
            "cache_control": {"type": "ephemeral"},
        }
    ],
    messages=[
        {
            "role": "user",
            "content": json.dumps({
                "observations": scrubbed_observations[-500:],
                "existing_instincts": index_instincts,
                "raw_proposals": proposals_from_session_learner,
            }),
        }
    ],
)
```

**Cache expectation:** the system block is byte-stable across every session.
Second call within 5 min TTL = ~90 % input-token discount.

### 3. Output contract

The model must return JSON of the form:

```json
{
  "proposals": [
    {
      "id": "kebab-case",
      "domain": "security|git|nextjs|...",
      "trigger_pattern": "regex",
      "inject": "<= 500 chars",
      "confidence": "HIGH|MEDIUM|LOW",
      "reasoning": "one-liner for the human review"
    }
  ]
}
```

`/analyze-session` validates the JSON, merges with existing regex proposals,
deduplicates by `id`, and presents to the user. Any invalid JSON falls back to
regex-only output.

### 4. Failure handling

- Missing `ANTHROPIC_API_KEY` → warn once, continue regex-only.
- API error / timeout (30 s cap) → log to `_sinapsis-debug.log`, continue
  regex-only. Never block the user.
- Malformed JSON → discard LLM proposals, continue with regex.

### 5. Architectural concern (open question)

Today Sinapsis is *core-deterministic*. Introducing an SDK call — even gated by
env var — opens a door to drift: future features could start relying on the LLM
branch and silently degrade without it. Mitigation:

- Keep the SDK branch strictly **additive** (merges with regex output, never
  replaces it).
- Add `test-v5-llm-fallback.sh` that exercises the `SINAPSIS_LLM_ANALYZE=0`
  path and asserts bit-identical output to v4.5.
- Document in README: "LLM analyze is a convenience layer. Sinapsis stays
  functional with it turned off."

## Rollout

- Phase 1 (this RFC): ship opt-in `SINAPSIS_LLM_ANALYZE`. Collect telemetry on
  cache-hit ratio and proposal quality for 2-3 weeks.
- Phase 2: if cache-hit ratio > 60 % and proposal acceptance rate > 40 %, make
  it default-on (still overridable).
- Phase 3 (speculative, multi-agent v5): Managed Agents on Anthropic Cloud
  fan out Scout(Sonnet 4.6) → Analyst(Sonnet 4.6) → Architect(Opus 4.7). Not
  covered here.

## Out of scope

- Memory tool (`memory_20250818`) integration. Sinapsis already *is* a memory
  system — adding the tool adds duplicate plumbing without a clear win. Revisit
  only if multi-machine sync becomes a real requirement.
- Context editing. Not applicable to `systemMessage` injection and adds cost.

## Not doing

- Haiku. Per operator preference, the Scout/Analyst/Architect blueprint skips
  Haiku entirely; Sonnet 4.6 is the lowest tier we use.
