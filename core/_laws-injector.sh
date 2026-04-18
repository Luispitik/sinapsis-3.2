#!/bin/bash
# Sinapsis v4.5 — Laws Injector (SessionStart hook)
#
# Always-injected one-liner tier: crystallized wisdom projected from permanent
# instincts (or fs-cortex seed stand-alones). Max 10 laws per session, cap ~300
# tokens, rotation by last_injected ASC for variety across sessions.
#
# Inspired by fs-cortex laws tier — credit: Fernando Montero (MIT, 2026).
#
# Model:
#   permanent instinct   (full entry in _instincts-index.json)
#       |
#       v   optionally distilled via /promote --law
#   Law                  (one-liner in _laws/<id>.txt, injected at SessionStart)

LAWS_DIR="$HOME/.claude/skills/_laws"

[ ! -d "$LAWS_DIR" ] && exit 0

if [ "${SINAPSIS_DEBUG:-}" = "1" ]; then
  exec 2>>"$HOME/.claude/skills/_sinapsis-debug.log"
fi

node -e '
const fs = require("fs");
const path = require("path");

const LAWS_DIR = process.env.HOME + "/.claude/skills/_laws";
const MAX_LAWS = 10;
const TOKEN_BUDGET = 300;   // conservative cap; Claude-style estimate ~4 chars/token
const CHARS_PER_TOKEN = 4;

function parseLaw(filePath) {
  const content = fs.readFileSync(filePath, "utf8");
  const m = content.match(/^---\r?\n([\s\S]*?)\r?\n---\r?\n([\s\S]*)$/);
  if (!m) return null;
  const fm = {};
  for (const line of m[1].split(/\r?\n/)) {
    const kv = line.match(/^([\w-]+):\s*(.*)$/);
    if (kv) fm[kv[1]] = kv[2].trim();
  }
  const text = m[2].trim().replace(/\s+/g, " ");
  if (!fm.id || !text) return null;
  return Object.assign(fm, { text, filePath });
}

let files;
try {
  files = fs.readdirSync(LAWS_DIR).filter(f => f.endsWith(".txt"));
} catch(e) { process.exit(0); }
if (!files.length) process.exit(0);

const laws = [];
for (const f of files) {
  try {
    const law = parseLaw(path.join(LAWS_DIR, f));
    if (law) laws.push(law);
  } catch(e) { /* skip malformed */ }
}
if (!laws.length) process.exit(0);

// Rotation: oldest last_injected first → round-robin variety over sessions.
laws.sort((a, b) => (a.last_injected || "").localeCompare(b.last_injected || ""));

const selected = [];
let tokenCount = 0;
for (const law of laws) {
  if (selected.length >= MAX_LAWS) break;
  const lawTokens = Math.ceil(law.text.length / CHARS_PER_TOKEN);
  if (tokenCount + lawTokens > TOKEN_BUDGET) break;
  selected.push(law);
  tokenCount += lawTokens;
}
if (!selected.length) process.exit(0);

for (const law of selected) {
  process.stdout.write("SESSION_PREFETCH_LAWS: " + law.text + "\n");
}

// Atomic last_injected update (write tmp → rename). Survives concurrent sessions.
const now = new Date().toISOString();
for (const law of selected) {
  try {
    const content = fs.readFileSync(law.filePath, "utf8");
    const updated = content.replace(/^(last_injected:\s*).*$/m, "$1" + now);
    const tmp = law.filePath + ".tmp";
    fs.writeFileSync(tmp, updated);
    fs.renameSync(tmp, law.filePath);
  } catch(e) { /* best-effort; next session retries */ }
}
' 2>/dev/null

exit 0
