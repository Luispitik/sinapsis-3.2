#!/bin/bash
# Instinct Activator - Sinapsis v4.2.1
# Reads tool data from stdin, matches against learned instincts, outputs systemMessage
# v4.2: occurrence tracking + auto-promote draft→confirmed at 5+ matches
# v4.2.1: occurrences tiebreaker in domain dedup + domain pre-filter by project stack
#         (inspired by fs-cortex project-scoped instincts — credit: Fernando Montero)

INDEX_FILE="$HOME/.claude/skills/_instincts-index.json"
LOG_FILE="$HOME/.claude/skills/_instinct.log"

[ ! -f "$INDEX_FILE" ] && exit 0

# v4.3.1: SINAPSIS_DEBUG mode (#22) — redirect stderr to log instead of /dev/null
if [ "${SINAPSIS_DEBUG:-}" = "1" ]; then
  exec 2>>"$HOME/.claude/skills/_sinapsis-debug.log"
fi

node -e '
const fs = require("fs");

let input = "";
process.stdin.setEncoding("utf8");
process.stdin.on("data", chunk => input += chunk);
process.stdin.on("end", () => {
  let data;
  try { data = JSON.parse(input); } catch(e) { process.exit(0); }

  const toolName = data.tool_name || data.tool || "";
  const toolInput = data.tool_input || data.input || {};
  const context = toolName + " " + (typeof toolInput === "object" ? JSON.stringify(toolInput) : String(toolInput));

  let index;
  try {
    index = JSON.parse(fs.readFileSync(process.env.HOME + "/.claude/skills/_instincts-index.json", "utf8"));
  } catch(e) { process.exit(0); }

  const instincts = index.instincts || [];

  // v4.2.1: domain pre-filter by project stack (inspired by fs-cortex project-scoped instincts)
  // Reads context.md to detect project tech, skips irrelevant domains. Reduces regex evals.
  const ALWAYS_DOMAINS = new Set(["_default", "general", "git", "security", "operations", "quality"]);
  let skipDomains = null; // null = no filtering (safe default)
  try {
    const cwd = data.cwd || "";
    if (cwd) {
      const { execFileSync } = require("child_process");
      const root = execFileSync("git", ["-C", cwd, "rev-parse", "--show-toplevel"],
        { stdio: ["pipe","pipe","pipe"], timeout: 2000 }).toString().trim();
      const crypto = require("crypto");
      let remote = "";
      try { remote = execFileSync("git", ["-C", root, "remote", "get-url", "origin"],
        { stdio: ["pipe","pipe","pipe"], timeout: 1000 }).toString().trim(); } catch(e) {}
      const hash = crypto.createHash("sha256").update(remote || root).digest("hex").slice(0, 12);
      const ctxPath = process.env.HOME + "/.claude/homunculus/projects/" + hash + "/context.md";
      if (fs.existsSync(ctxPath)) {
        const ctx = fs.readFileSync(ctxPath, "utf8").toLowerCase();
        const stackDomains = new Set(ALWAYS_DOMAINS);
        // Detect tech from context.md and allow matching domains
        if (/next|react|tsx|jsx/.test(ctx)) { stackDomains.add("nextjs"); stackDomains.add("react"); stackDomains.add("frontend"); }
        if (/supabase|rls|postgres/.test(ctx)) { stackDomains.add("database"); stackDomains.add("supabase"); stackDomains.add("auth"); }
        if (/stripe|payment|billing/.test(ctx)) { stackDomains.add("stripe"); stackDomains.add("billing"); }
        if (/prisma|schema\.prisma/.test(ctx)) { stackDomains.add("prisma"); stackDomains.add("orm"); }
        if (/docker|container/.test(ctx)) stackDomains.add("docker");
        if (/python|django|flask/.test(ctx)) stackDomains.add("python");
        if (/formaci|training|curso/.test(ctx)) stackDomains.add("formacion");
        if (/contrato|nda|dpa|propuesta/.test(ctx)) stackDomains.add("contratos");
        if (/content|brand|copper|salgado/.test(ctx)) stackDomains.add("content");
        if (/remotion|video/.test(ctx)) stackDomains.add("video");
        if (/vercel|deploy/.test(ctx)) stackDomains.add("deploy");
        skipDomains = stackDomains;
      }
    }
  } catch(e) { /* no context = no filtering, safe */ }

  const matches = [];

  for (const inst of instincts) {
    if (!inst.trigger_pattern) continue;
    // v4.3.1: drafts participate in matching for occurrence tracking + auto-promote
    // but are NOT injected into context (only confirmed/permanent inject)
    const isDraft = inst.level === "draft";
    // v4.2.1: skip instincts from irrelevant domains (if project context available)
    if (skipDomains && inst.domain && !skipDomains.has(inst.domain)) continue;
    try {
      // v4.3.1: ReDoS protection — reject patterns with nested quantifiers
      const tp = inst.trigger_pattern;
      if (/(\+|\*|\{)\)?(\+|\*|\{)/.test(tp)) continue; // skip catastrophic backtracking patterns
      if (!new RegExp(tp, "i").test(context)) continue;
    } catch(e) { continue; }
    matches.push(inst);
  }

  if (!matches.length) process.exit(0);

  // Separate drafts from injectable instincts
  const draftMatches = matches.filter(m => m.level === "draft");
  const injectableMatches = matches.filter(m => m.level !== "draft");

  // Priority sort: permanent first, then confirmed; within same level, highest occurrences wins
  // v4.2.1: occurrences tiebreaker (inspired by fs-cortex confidence granularity)
  const order = { permanent: 0, confirmed: 1 };
  injectableMatches.sort((a, b) => {
    const lvl = (order[a.level] ?? 2) - (order[b.level] ?? 2);
    if (lvl !== 0) return lvl;
    return (b.occurrences || 0) - (a.occurrences || 0); // higher occurrences = higher priority
  });

  // Deduplicate by domain — keep only highest priority match per domain
  const domainMap = {};
  for (const m of injectableMatches) {
    const d = m.domain || "_default";
    if (!domainMap[d]) domainMap[d] = m; // already sorted, first = highest priority
  }
  const top = Object.values(domainMap).slice(0, 3);

  // v4.3.1: sanitize inject content (#5F — prompt injection prevention)
  const INJECT_MAX_LEN = 500;
  const INJECT_BLOCKED = /ignore\s+(previous|above|all)\s+instructions|system:\s*you\s+are|<\/?system>|<\/?prompt>/i;

  // Only output systemMessage if there are injectable matches
  if (top.length > 0) {
    const msgs = top
      .filter(m => !INJECT_BLOCKED.test(m.inject || ""))
      .map(m => "[instinct] " + (m.inject || "").slice(0, INJECT_MAX_LEN));
    if (msgs.length > 0) {
      console.log(JSON.stringify({ systemMessage: msgs.join("\n\n") }));
    }
  }

  // v4.3.1: Occurrence tracking for ALL matches (including drafts) + auto-promote
  const now = new Date().toISOString();
  let promoted = [];
  try {
    const allMatchedIds = new Set([...top.map(m => m.id), ...draftMatches.map(m => m.id)]);
    let dirty = false;
    for (const inst of index.instincts) {
      if (!allMatchedIds.has(inst.id)) continue;
      inst.occurrences = (inst.occurrences || 0) + 1;
      inst.last_triggered = now;
      if (!inst.first_triggered) inst.first_triggered = now;
      dirty = true;
      // Auto-promote: draft with 5+ occurrences → confirmed
      if (inst.level === "draft" && inst.occurrences >= 5) {
        inst.level = "confirmed";
        promoted.push(inst.id);
      }
    }
    if (dirty) {
      const indexPath = process.env.HOME + "/.claude/skills/_instincts-index.json";
      // v4.3.1: skip write if dream cycle holds the lock (#6 race condition)
      const dreamLock = process.env.HOME + "/.claude/skills/_dream.lock";
      if (fs.existsSync(dreamLock)) {
        // Dream cycle is running — skip write to avoid data loss
      } else {
        const tmpPath = indexPath + ".tmp";
        fs.writeFileSync(tmpPath, JSON.stringify(index, null, 2));
        fs.renameSync(tmpPath, indexPath);
      }
    }
  } catch(e) {}

  // Log activations (audit trail — kept as backup)
  try {
    const ids = top.map(m => m.id).join(",");
    const promoMsg = promoted.length > 0 ? " | PROMOTED:" + promoted.join(",") : "";
    fs.appendFileSync(process.env.HOME + "/.claude/skills/_instinct.log",
      now + " | " + toolName + " | " + ids + promoMsg + "\n");
  } catch(e) {}
});
' 2>/dev/null

exit 0
