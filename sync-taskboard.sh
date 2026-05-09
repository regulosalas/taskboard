#!/bin/bash
# sync-taskboard.sh — Convierte TASKBOARD.md a taskboard/taskboard.json
# y hace push a GitHub Pages

MD_FILE="$HOME/.openclaw/workspace/TASKBOARD.md"
JSON_FILE="$HOME/.openclaw/workspace/taskboard/taskboard.json"
REPO_DIR="$HOME/.openclaw/workspace/taskboard"

if [ ! -f "$MD_FILE" ]; then
  echo '{"backlog":[],"todo":[],"in_progress":[],"done":[]}' > "$JSON_FILE"
  exit 0
fi

node -e '
const fs = require("fs");
const md = fs.readFileSync("'"$MD_FILE"'", "utf8");

const sections = { backlog: "Backlog", todo: "To Do", in_progress: "In Progress", done: "Done" };
const result = { backlog: [], todo: [], in_progress: [], done: [] };
let currentSection = null;
let inCodeBlock = false;

for (const line of md.split("\n")) {
  const t = line.trim();
  if (!t) continue;
  if (t.startsWith("```")) { inCodeBlock = !inCodeBlock; continue; }
  if (inCodeBlock) continue;

  if (t.startsWith("## ")) {
    const header = t.replace(/^##\s*\S*\s*/, "").replace(/\*\*/g,"").trim();
    for (const [k, lbl] of Object.entries(sections)) {
      if (header.includes(lbl)) { currentSection = k; break; }
    }
    continue;
  }

  if (!t.startsWith("- [") || !currentSection || !result[currentSection]) continue;
  const m = t.match(/^-\s*\[\s*([ >x])\s*\]\s*(.*)/);
  if (!m) continue;
  let text = m[2].trim();
  if (text.includes("acá") || text.includes("Descripción") || text.includes("Título")) continue;

  let priority = "normal";
  if (text.includes("@urgente")) priority = "urgente";
  else if (text.includes("@importante")) priority = "importante";
  else if (text.includes("@baja")) priority = "baja";

  let est = null;
  const em = text.match(/@estimado:([\dhms]+)/);
  if (em) est = em[1];

  const tags = (text.match(/#(\w+)/g)||[]).map(x=>x.replace("#",""));

  let created = null;
  const dm = text.match(/\(creada:\s*([^)]+)\)/);
  if (dm) created = dm[1].trim();

  let title = text
    .replace(/@urgente/g,"").replace(/@importante/g,"").replace(/@normal/g,"").replace(/@baja/g,"")
    .replace(/@estimado:[\dhms]+/g,"").replace(/#\w+/g,"").replace(/\(creada:[^)]+\)/g,"")
    .replace(/\s+/g," ").trim();

  if (title) result[currentSection].push({ title, priority, tags, created, estimate: est });
}

fs.writeFileSync("'"$JSON_FILE"'", JSON.stringify(result, null, 2));
'

cd "$REPO_DIR"
git add -A
git diff --cached --quiet && exit 0
git commit -m "taskboard: auto-sync $(date +%Y-%m-%d_%H:%M)" --quiet
git push origin main --quiet 2>&1 || echo "⚠️ Push falló (revisa conexión)"
