#!/bin/bash
# EOD Gather — Multi-project activity collector
# Sinapsis v4.2.2
# Scans homunculus/projects/ for today's observations across ALL projects.
# Outputs JSON with project names, observation counts, tools used, and git data.
# Called by /eod command — replaces single-project git scan.
# NO LLM. Pure deterministic Node.js.

HOMUNCULUS="$HOME/.claude/homunculus"

if [ "${SINAPSIS_DEBUG:-}" = "1" ]; then
  exec 2>>"$HOME/.claude/skills/_sinapsis-debug.log"
fi

[ ! -d "$HOMUNCULUS/projects" ] && echo '{"date":"'$(date -u +%Y-%m-%d)'","project_count":0,"projects":[]}' && exit 0

node -e '
const fs = require("fs");
const path = require("path");
const { execFileSync } = require("child_process");

const HOME = process.env.HOME || process.env.USERPROFILE || "";
const homunculus = HOME + "/.claude/homunculus";
const projectsDir = path.join(homunculus, "projects");
const today = new Date().toISOString().slice(0, 10);

// Load project registry for names and roots
let registry = {};
try {
  registry = JSON.parse(fs.readFileSync(path.join(homunculus, "projects.json"), "utf8"));
} catch(e) {}

const projects = [];

let entries;
try { entries = fs.readdirSync(projectsDir); } catch(e) { entries = []; }

for (const hash of entries) {
  const obsFile = path.join(projectsDir, hash, "observations.jsonl");
  if (!fs.existsSync(obsFile)) continue;

  let lines;
  try {
    lines = fs.readFileSync(obsFile, "utf8").trim().split("\n");
  } catch(e) { continue; }

  // Filter to today only
  const todayLines = [];
  for (const line of lines) {
    try {
      const obj = JSON.parse(line);
      if (obj.timestamp && obj.timestamp.startsWith(today)) {
        todayLines.push(obj);
      }
    } catch(e) {}
  }

  if (todayLines.length === 0) continue;

  const info = registry[hash] || {};
  const projectName = info.name || hash;
  const projectRoot = info.root || "";

  // Extract tools used today (unique)
  const tools = [...new Set(todayLines.filter(l => l.tool).map(l => l.tool))];

  // Count errors
  const errorCount = todayLines.filter(l => l.is_error).length;

  // Files touched (from Edit/Write inputs)
  const filesTouched = [...new Set(
    todayLines
      .filter(l => l.event === "tool_complete" && (l.tool === "Edit" || l.tool === "Write"))
      .map(l => {
        try {
          const inp = JSON.parse(l.input || "{}");
          return inp.file_path ? path.basename(inp.file_path) : null;
        } catch(e) { return null; }
      })
      .filter(Boolean)
  )].slice(0, 15);

  // Git data (if root exists)
  let gitData = null;
  if (projectRoot && fs.existsSync(projectRoot)) {
    try {
      const branch = execFileSync("git", ["-C", projectRoot, "branch", "--show-current"],
        { stdio: ["pipe", "pipe", "pipe"], timeout: 3000 }
      ).toString().trim();

      let commits = "";
      try {
        const author = execFileSync("git", ["-C", projectRoot, "config", "user.email"],
          { stdio: ["pipe", "pipe", "pipe"], timeout: 2000 }
        ).toString().trim();
        if (author) {
          commits = execFileSync("git", ["-C", projectRoot, "log", "--oneline", "--since=00:00", "--author=" + author],
            { stdio: ["pipe", "pipe", "pipe"], timeout: 5000 }
          ).toString().trim();
        }
      } catch(e) {
        try {
          commits = execFileSync("git", ["-C", projectRoot, "log", "--oneline", "--since=00:00"],
            { stdio: ["pipe", "pipe", "pipe"], timeout: 5000 }
          ).toString().trim();
        } catch(e2) {}
      }

      let status = "";
      try {
        status = execFileSync("git", ["-C", projectRoot, "status", "-s"],
          { stdio: ["pipe", "pipe", "pipe"], timeout: 3000 }
        ).toString().trim();
      } catch(e) {}

      gitData = {
        branch: branch,
        commits_today: commits ? commits.split("\n").length : 0,
        commits_log: commits || "(no commits today)",
        uncommitted_files: status ? status.split("\n").length : 0,
        status: status || "(clean)"
      };
    } catch(e) {
      // Not a git repo or git error — skip git data
    }
  }

  // Read context.md if available
  let contextMd = null;
  const ctxFile = path.join(projectsDir, hash, "context.md");
  if (fs.existsSync(ctxFile)) {
    try { contextMd = fs.readFileSync(ctxFile, "utf8").trim(); } catch(e) {}
  }

  projects.push({
    hash,
    name: projectName,
    root: projectRoot,
    observations_today: todayLines.length,
    tools_used: tools,
    files_touched: filesTouched,
    errors_today: errorCount,
    git: gitData,
    context: contextMd
  });
}

// Sort by observation count descending (most active first)
projects.sort((a, b) => b.observations_today - a.observations_today);

const result = {
  date: today,
  project_count: projects.length,
  total_observations: projects.reduce((sum, p) => sum + p.observations_today, 0),
  projects
};

console.log(JSON.stringify(result, null, 2));
' 2>/dev/null

exit 0
