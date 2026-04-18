# Seed laws

One-liner crystallized wisdom. Shipped with install, copied to `~/.claude/skills/_laws/`, injected at SessionStart by `_laws-injector.sh` (max 10, cap ~300 tokens, rotation by `last_injected`).

## Schema

```
---
id: <kebab-case-id>
source_instinct: <instinct_id | null>
source: <origin tag>
license: <MIT or omit>
created: <YYYY-MM-DD>
last_injected: <ISO-8601 | 1970-01-01T00:00:00Z>
---
<one-line text, <=40 tokens>
```

`source_instinct: null` = stand-alone seed with no instinct counterpart. When `/promote --law` distills a permanent instinct, `source_instinct` points to that instinct id.

## Seeds shipped

All 5 ported from [fermontero/fs-cortex](https://github.com/fermonterom/fs-cortex) (MIT © 2026 Fernando Montero):

- read-first
- grep-read-verify
- git-triple-check
- never-hardcode-secrets
- three-layer-security
