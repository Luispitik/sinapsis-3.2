#!/bin/bash
# Project Context Injector - Sinapsis v4.1
# PreToolUse (sync, 3s): injects last-session context for the current project.
# Fires ONCE per session using session_id as flag. Bridges context between sessions.
#
# Injects two sources (if available):
#   1. homunculus/projects/{hash}/context.md  — technical context (files, errors)
#   2. skills/_daily-summaries/YYYY-MM-DD.md  — EOD summary (intent, priorities)
#
# Writes: nothing (read-only hook)

HOMUNCULUS="$HOME/.claude/homunculus"
[ ! -d "$HOMUNCULUS" ] && exit 0

node -e '
const fs = require("fs");
const path = require("path");
const crypto = require("crypto");
const os = require("os");
const { execSync } = require("child_process");

let input = "";
process.stdin.setEncoding("utf8");
process.stdin.on("data", chunk => input += chunk);
process.stdin.on("end", () => {
  let data;
  try { data = JSON.parse(input); } catch(e) { process.exit(0); }

  const sessionId = (data.session_id || "unknown").slice(0, 16);
  const cwd = data.cwd || "";

  // Fire only once per session (flag in os.tmpdir)
  const flagFile = path.join(os.tmpdir(), "sinapsis-ctx-" + sessionId);
  if (fs.existsSync(flagFile)) process.exit(0);
  try { fs.writeFileSync(flagFile, "1"); } catch(e) {}

  const HOME = process.env.HOME || process.env.USERPROFILE || "";
  const parts = [];

  // ── SOURCE 1: EOD daily summary (intent + priorities) ──
  // Check today then yesterday — most recent wins
  const today = new Date();
  const fmt = d => d.toISOString().slice(0, 10);
  const yesterday = new Date(today); yesterday.setDate(today.getDate() - 1);

  for (const day of [fmt(today), fmt(yesterday)]) {
    const eodFile = HOME + "/.claude/skills/_daily-summaries/" + day + ".md";
    if (!fs.existsSync(eodFile)) continue;
    try {
      const eod = fs.readFileSync(eodFile, "utf8").trim();
      if (eod) {
        parts.push("[eod-summary " + day + "]\n" + eod);
        break; // Only inject the most recent one
      }
    } catch(e) {}
  }

  // ── SOURCE 2: Technical context.md (files touched, errors) ──
  // Only works for git projects
  if (!cwd || !fs.existsSync(cwd)) {
    if (parts.length > 0) {
      console.log(JSON.stringify({ systemMessage: parts.join("\n\n") }));
    }
    process.exit(0);
  }

  let projectHash;
  try {
    const root = execSync(
      "git -C " + JSON.stringify(cwd) + " rev-parse --show-toplevel",
      { stdio: ["pipe", "pipe", "pipe"], timeout: 3000 }
    ).toString().trim();
    let remote = "";
    try {
      remote = execSync(
        "git -C " + JSON.stringify(root) + " remote get-url origin",
        { stdio: ["pipe", "pipe", "pipe"], timeout: 2000 }
      ).toString().trim();
    } catch(e) {}
    projectHash = crypto.createHash("sha256").update(remote || root).digest("hex").slice(0, 12);
  } catch(e) {
    // Not a git project — still inject EOD if available
    if (parts.length > 0) {
      console.log(JSON.stringify({ systemMessage: parts.join("\n\n") }));
    }
    process.exit(0);
  }

  const contextFile = HOME + "/.claude/homunculus/projects/" + projectHash + "/context.md";
  if (fs.existsSync(contextFile)) {
    try {
      const context = fs.readFileSync(contextFile, "utf8").trim();
      if (context) {
        // Only inject technical context if recent (< 14 days)
        const stats = fs.statSync(contextFile);
        const ageDays = (Date.now() - stats.mtimeMs) / 86400000;
        if (ageDays <= 14) {
          parts.push("[project-context]\n" + context);
        }
      }
    } catch(e) {}
  }

  if (parts.length === 0) process.exit(0);
  console.log(JSON.stringify({ systemMessage: parts.join("\n\n") }));
});
' 2>/dev/null

exit 0
