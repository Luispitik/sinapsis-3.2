---
name: restore
description: Import Sinapsis state from a backup folder (created by /backup) into this machine
command: true
---

# /restore [source-path]

> Import Sinapsis state from a backup folder into this machine.
> Merges intelligently — does not overwrite instincts you've learned locally.

## Trigger

`/restore`, `/restore <path>`, "restore sinapsis", "import sinapsis backup", "sync from backup"

Common paths by platform:
- Windows OneDrive: `/restore ~/OneDrive/sinapsis-sync`
- Windows Google Drive: `/restore "C:/Users/{user}/Google Drive/My Drive/sinapsis-sync"`
- macOS iCloud: `/restore ~/Library/Mobile\ Documents/com~apple~CloudDocs/sinapsis-sync`
- macOS Google Drive: `/restore ~/Library/CloudStorage/GoogleDrive-{email}/My\ Drive/sinapsis-sync`
- Dropbox (any OS): `/restore ~/Dropbox/sinapsis-sync`

## Process

### Step 1: Locate backup

If user provides a path: use it.
Default: `~/.claude/sinapsis-backup/`

Verify `manifest.json` exists. If not, abort: "No valid Sinapsis backup found at {path}. Run /backup on the source machine first."

### Step 2: Read manifest and show summary

```
Backup found: v4.3.3, exported 2026-04-13 from {hostname}
  - {N} instincts ({C} confirmed, {P} permanent)
  - {R} passive rules
  - {M} commands

Local state:
  - {N2} instincts, {R2} passive rules, {M2} commands

Merge strategy:
  [1] Merge (add missing, keep local) — RECOMMENDED
  [2] Replace (overwrite local with backup)
  [3] Cancel
```

### Step 3: Merge instincts

For each instinct in the backup:
- If ID exists locally with same level → skip (keep local, it has local occurrence data)
- If ID exists locally with different level → keep the higher level
- If ID does NOT exist locally → add it (mark `origin: "imported"`)
- Preserve local `occurrences`, `sessions_seen`, `first_triggered`, `last_triggered`

### Step 4: Merge passive rules

Same logic as instincts — merge by ID, don't duplicate.

### Step 5: Merge operator state

- `operator.name`, `operator.brands`, `operator.locale` → take from backup (identity)
- `stackDecisions` → take from backup (these are strategic, should be consistent)
- `strategicDecisions` → merge by ID (add missing, don't duplicate)
- `pendingMilestones` → merge by ID

### Step 6: Copy commands (non-destructive)

For each command in the backup:
- If not present locally → copy
- If present locally → skip (keep local version, it may have been customized)

### Step 7: Settings.json and CLAUDE.md

These are machine-specific. Show diff if they differ, ask user:
```
settings.json differs between backup and local.
  [1] Keep local (recommended — hooks may differ per machine)
  [2] Show diff
  [3] Replace with backup
```

### Step 8: Report

```
Restore complete:
  - Instincts: {added} added, {skipped} already present, {upgraded} upgraded
  - Passive rules: {added} added, {skipped} skipped
  - Commands: {added} new commands installed
  - Operator state: merged {N} decisions

Your Sinapsis is now synced with the backup from {hostname}.
```

## Important Rules

1. **Always merge, never blindly overwrite** — the user may have local instincts not in the backup
2. **Preserve local occurrence data** — occurrences and sessions_seen are machine-specific tracking
3. **Ask before overwriting CLAUDE.md or settings.json** — these are machine-dependent
4. **Log the restore** to `_instinct.log`: `{date} | RESTORE | from {hostname} | {N} instincts imported`
