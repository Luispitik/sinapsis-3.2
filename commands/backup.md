---
name: backup
description: Export full Sinapsis state to a portable folder for sync or migration to another machine
command: true
---

# /backup [target-path]

> Export your entire Sinapsis learning state to a portable folder.
> Use to sync between machines, create snapshots, or migrate to a new computer.

## Trigger

`/backup`, `/backup ~/OneDrive/sinapsis-sync`, "backup sinapsis", "export my sinapsis", "sync sinapsis"

## Process

### Step 1: Determine target path

If user provides a path: use it.
Default: `~/.claude/sinapsis-backup/`

Create the directory if it doesn't exist.

### Step 2: Export state files

Copy these files to the target, preserving the relative structure:

```
{target}/
  manifest.json                    ← version, date, hostname, file list, stats
  skills/
    _instincts-index.json          ← learned instincts (THE critical file)
    _passive-rules.json            ← passive rules
    _operator-state.json           ← identity + strategic decisions
    _instinct-proposals.json       ← pending proposals
    _instinct.log                  ← activation audit trail
    _passive.log                   ← passive rule audit trail
    _projects.json                 ← project registry
  commands/                        ← all installed slash commands (*.md)
  CLAUDE.md                        ← entry point
  settings.json                    ← hook configuration
```

### Step 3: Generate manifest.json

```json
{
  "version": "4.3.3",
  "exported_at": "2026-04-13T15:30:00Z",
  "hostname": "{hostname}",
  "platform": "{platform}",
  "stats": {
    "instincts": 38,
    "instincts_confirmed": 12,
    "instincts_permanent": 5,
    "passive_rules": 6,
    "commands": 14,
    "projects_registered": 8
  },
  "files": ["list of all exported files with sizes"]
}
```

### Step 4: Report

```
Sinapsis backup complete → {target}/
  - {N} instincts ({C} confirmed, {P} permanent)
  - {R} passive rules
  - {M} commands
  - manifest.json with full inventory

To restore on another machine:
  1. Install Sinapsis: git clone https://github.com/Luispitik/sinapsis && bash install.sh
  2. Run: /restore {target}/
```

## What is NOT exported (and why)

- `homunculus/projects/*/observations.jsonl` — raw data, large, machine-specific. Knowledge is already in instincts.
- `homunculus/projects/*/context.md` — regenerated every session
- `_daily-summaries/` — ephemeral session data
- `_dream.lock`, `_dream.log`, `_dream-report.md` — transient dream cycle artifacts
- `_session-learner.log` — transient log

## For continuous sync (any cloud provider)

The backup is a plain folder — any cloud sync service works. Run `/backup` with your sync path:

**Windows:**
- OneDrive: `/backup ~/OneDrive/sinapsis-sync`
- Google Drive: `/backup ~/Google\ Drive/sinapsis-sync` or `/backup "C:/Users/{user}/Google Drive/My Drive/sinapsis-sync"`
- Dropbox: `/backup ~/Dropbox/sinapsis-sync`

**macOS:**
- iCloud: `/backup ~/Library/Mobile\ Documents/com~apple~CloudDocs/sinapsis-sync`
- Google Drive: `/backup ~/Library/CloudStorage/GoogleDrive-{email}/My\ Drive/sinapsis-sync`
- OneDrive: `/backup ~/Library/CloudStorage/OneDrive-Personal/sinapsis-sync`
- Dropbox: `/backup ~/Dropbox/sinapsis-sync`

**Linux:**
- Google Drive (rclone): `/backup ~/gdrive/sinapsis-sync`
- Dropbox: `/backup ~/Dropbox/sinapsis-sync`
- Any mounted share: `/backup /mnt/sync/sinapsis-sync`

**USB / manual:** `/backup /path/to/usb/sinapsis-sync`

No network connection needed between machines — the cloud service handles sync.
Run periodically or after `/evolve` sessions.

## Important Rules

1. **Never overwrite** the target if it already exists — merge or ask
2. **Always generate manifest** — it's the integrity check for /restore
3. **Scrub secrets** — verify operator-state doesn't contain API keys before exporting
4. **Report size** — user should know how much space this takes
