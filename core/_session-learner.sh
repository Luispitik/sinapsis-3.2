#!/bin/bash
# Session Learner - Sinapsis v4.2
# Stop hook: three jobs —
#   1. Detect patterns (error-fix, user-corrections, workflow-chains) → _instinct-proposals.json
#   2. Write context.md per project → picked up by _project-context.sh next session
#   3. Enrich proposals with project context and sample data
# NO LLM. Pure deterministic Node.js.

HOMUNCULUS="$HOME/.claude/homunculus"

if [ "${SINAPSIS_DEBUG:-}" = "1" ]; then
  exec 2>>"$HOME/.claude/skills/_sinapsis-debug.log"
fi

INDEX_FILE="$HOME/.claude/skills/_instincts-index.json"
PROPOSALS_FILE="$HOME/.claude/skills/_instinct-proposals.json"
LOG_FILE="$HOME/.claude/skills/_session-learner.log"

# Find the most recently MODIFIED observations file (fix #17: was selecting by hash, not recency)
OBS_FILE=""
if [ -d "$HOMUNCULUS/projects" ]; then
  # Portable: use stat instead of GNU find -printf (works on macOS + Linux + Git Bash)
  OBS_FILE=$(find "$HOMUNCULUS/projects" -name "observations.jsonl" -newer "$HOMUNCULUS/.last-learn" 2>/dev/null | while read -r f; do echo "$(stat -c '%Y' "$f" 2>/dev/null || stat -f '%m' "$f" 2>/dev/null || echo 0) $f"; done | sort -rn | head -1 | cut -d' ' -f2-)
  [ -z "$OBS_FILE" ] && OBS_FILE=$(find "$HOMUNCULUS/projects" -name "observations.jsonl" -size +0c 2>/dev/null | while read -r f; do echo "$(stat -c '%Y' "$f" 2>/dev/null || stat -f '%m' "$f" 2>/dev/null || echo 0) $f"; done | sort -rn | head -1 | cut -d' ' -f2-)
fi

[ -z "$OBS_FILE" ] && exit 0
[ ! -s "$OBS_FILE" ] && exit 0

node -e '
const fs = require("fs");
const path = require("path");

const obsFile = process.argv[1];
const indexFile = process.argv[2];
const proposalsFile = process.argv[3];
const logFile = process.argv[4];

// Read last 1000 lines of observations (v4.2: was 100, covers parallel sessions)
let lines;
try {
  const content = fs.readFileSync(obsFile, "utf8").trim().split("\n");
  lines = content.slice(-1000).map(l => { try { return JSON.parse(l); } catch(e) { return null; } }).filter(Boolean);
} catch(e) { process.exit(0); }

if (lines.length < 3) process.exit(0);

// ── JOB 1: Write project context.md (ALWAYS — not just when proposals exist) ──
const projectDir = path.dirname(obsFile);
const projectHash = path.basename(projectDir);
const today = new Date().toISOString().slice(0, 10);

// Get project name (hoisted — used by JOB 1 and JOB 2)
let projectName = projectHash;
try {
  const pj = JSON.parse(fs.readFileSync(process.env.HOME + "/.claude/homunculus/projects.json", "utf8"));
  if (pj[projectHash] && pj[projectHash].name) projectName = pj[projectHash].name;
} catch(e) {}

try {
  // Get total obs count from full file
  let totalObs = lines.length;
  try {
    totalObs = fs.readFileSync(obsFile, "utf8").trim().split("\n").length;
  } catch(e) {}

  // Files touched this session (Edit/Write, deduplicated, max 6)
  const filesTouched = [...new Set(
    lines
      .filter(l => l.event === "tool_complete" && (l.tool === "Edit" || l.tool === "Write"))
      .map(l => {
        try {
          const inp = JSON.parse(l.input || "{}");
          return inp.file_path ? path.basename(inp.file_path) : null;
        } catch(e) { return null; }
      })
      .filter(Boolean)
  )].slice(0, 6);

  // Error patterns count (for proposals hint)
  let errorCount = 0;
  for (let i = 0; i < lines.length - 1; i++) {
    if (!lines[i].is_error) continue;
    for (let j = i+1; j < Math.min(i+6, lines.length); j++) {
      if (lines[j].tool === lines[i].tool && !lines[j].is_error) {
        errorCount++;
        break;
      }
    }
  }

  const contextLines = [
    "## Proyecto: " + projectName,
    "Última sesión: " + today,
    "Observaciones totales: " + totalObs,
    filesTouched.length > 0
      ? "Archivos activos: " + filesTouched.join(", ")
      : null,
    errorCount > 0
      ? "Posibles gotchas detectados: " + errorCount + " — ejecuta /analyze-session"
      : null,
  ].filter(Boolean).join("\n");

  fs.writeFileSync(projectDir + "/context.md", contextLines);
} catch(e) {
  // context.md write failure is non-critical
}

// ── JOB 2: Detect error-resolution patterns → proposals ──

// Read existing instincts to avoid re-proposing known patterns
let existing = new Set();
try {
  const idx = JSON.parse(fs.readFileSync(indexFile, "utf8"));
  (idx.instincts || []).forEach(i => existing.add(i.id));
} catch(e) {}

// Load proposals for today (session-based, overwrites on new day)
let proposals;
try {
  const raw = JSON.parse(fs.readFileSync(proposalsFile, "utf8"));
  proposals = (raw.session_date === today) ? raw : { version: "1.0", session_date: today, proposals: [] };
} catch(e) {
  proposals = { version: "1.0", session_date: today, proposals: [] };
}

// IDs already proposed today
const proposedIds = new Set(proposals.proposals.map(p => p.id));
const found = [];

// PATTERN 1: error → same tool success within 5 events (uses is_error flag from observe_v3)
// Dedup: one proposal per tool per day
for (let i = 0; i < lines.length - 1; i++) {
  if (!lines[i].is_error) continue;

  const toolId = "fix-" + lines[i].tool.toLowerCase().replace(/[^a-z]/g, "");
  if (existing.has(toolId) || proposedIds.has(toolId)) continue;

  for (let j = i+1; j < Math.min(i+6, lines.length); j++) {
    if (lines[j].tool === lines[i].tool && !lines[j].is_error) {
      found.push({
        type: "error_resolution",
        id: toolId,
        description: lines[i].tool + " error resuelto — posible gotcha a documentar",
        evidence: "Sesion " + today + ": fallo y recuperacion en misma herramienta",
        project_name: projectName,
        sample_input: (lines[i].input || "").slice(0, 200),
        sample_output: (lines[i].output || "").slice(0, 200),
        err_msg: (lines[i].err_msg || "").slice(0, 200),
        is_critical: !!lines[i].is_critical
      });
      proposedIds.add(toolId);
      break;
    }
  }
}

// PATTERN 2: user corrections — Edit/Write on same file within 10 events = refinement
// v4.2: detects when user iterates on same file (correction/preference signal)
const editEvents = lines
  .map((l, idx) => ({ ...l, _idx: idx }))
  .filter(l => l.event === "tool_complete" && (l.tool === "Edit" || l.tool === "Write"));

const correctedFiles = {};
for (let i = 0; i < editEvents.length - 1; i++) {
  let fileA = "";
  try { const inp = JSON.parse(editEvents[i].input || "{}"); fileA = inp.file_path || ""; } catch(e) {}
  if (!fileA) continue;

  for (let j = i + 1; j < editEvents.length; j++) {
    if (editEvents[j]._idx - editEvents[i]._idx > 10) break; // window of 10 events
    let fileB = "";
    try { const inp = JSON.parse(editEvents[j].input || "{}"); fileB = inp.file_path || ""; } catch(e) {}
    if (fileA === fileB) {
      const slug = path.basename(fileA).toLowerCase().replace(/[^a-z0-9]/g, "-").replace(/-+/g, "-").slice(0, 30);
      correctedFiles[slug] = (correctedFiles[slug] || 0) + 1;
      break;
    }
  }
}

for (const [slug, count] of Object.entries(correctedFiles)) {
  if (count < 2) continue; // need at least 2 correction cycles
  const corrId = "correction-" + slug;
  if (existing.has(corrId) || proposedIds.has(corrId)) continue;
  found.push({
    type: "user_correction",
    id: corrId,
    description: "Archivo " + slug + " editado " + (count + 1) + "+ veces — posible patron de correccion",
    evidence: "Sesion " + today + ": " + count + " ciclos de re-edicion en mismo archivo",
    project_name: projectName,
    sample_input: "",
    sample_output: ""
  });
  proposedIds.add(corrId);
}

// PATTERN 3: workflow chains — same sequence of 3+ tools appears 2+ times
// v4.2: detects repeated tool sequences (workflow signal)
const toolSeq = lines
  .filter(l => l.event === "tool_complete")
  .map(l => l.tool);

if (toolSeq.length >= 6) {
  const trigramCounts = {};
  for (let i = 0; i <= toolSeq.length - 3; i++) {
    const key = toolSeq[i] + ">" + toolSeq[i+1] + ">" + toolSeq[i+2];
    trigramCounts[key] = (trigramCounts[key] || 0) + 1;
  }

  for (const [seq, count] of Object.entries(trigramCounts)) {
    if (count < 2) continue;
    const parts = seq.split(">");
    const wfId = "workflow-" + parts.map(p => p.toLowerCase().replace(/[^a-z]/g, "")).join("-");
    if (existing.has(wfId) || proposedIds.has(wfId)) continue;
    found.push({
      type: "workflow_chain",
      id: wfId,
      description: parts.join(" → ") + " repetido " + count + "x — posible workflow a documentar",
      evidence: "Sesion " + today + ": secuencia de 3 tools repetida " + count + " veces",
      project_name: projectName,
      sample_input: "",
      sample_output: ""
    });
    proposedIds.add(wfId);
  }
}

const now = new Date().toISOString();

// Write proposals (only if new ones found)
if (found.length > 0) {
  found.forEach(f => {
    proposals.proposals.push({ ...f, proposed_at: now, status: "pending", level: "draft" });
  });
  try { fs.writeFileSync(proposalsFile, JSON.stringify(proposals, null, 2)); } catch(e) {}
}

// Touch marker
try {
  fs.writeFileSync(process.env.HOME + "/.claude/homunculus/.last-learn", now);
} catch(e) {}

// Log
try {
  const summary = found.length > 0
    ? found.length + " patterns: " + found.map(f => f.id).join(",")
    : "no patterns";
  fs.appendFileSync(logFile, now + " | " + summary + " | context.md written for " + projectHash + "\n");
} catch(e) {}

// Output systemMessage only if proposals found
if (found.length > 0) {
  const msg = "Sinapsis: " + found.length + " patron(es) detectado(s):\n" +
    found.map(f => "  - " + f.description).join("\n") +
    "\nRevisa con /analyze-session.";
  console.log(JSON.stringify({ systemMessage: msg }));
}
' "$OBS_FILE" "$INDEX_FILE" "$PROPOSALS_FILE" "$LOG_FILE" 2>/dev/null

exit 0
