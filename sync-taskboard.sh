#!/bin/bash
# sync-taskboard.sh — Convierte TASKBOARD.md a taskboard/taskboard.json
# y hace push a GitHub Pages

MD_FILE="$HOME/.openclaw/workspace/TASKBOARD.md"
JSON_FILE="$HOME/.openclaw/workspace/taskboard/taskboard.json"
REPO_DIR="$HOME/.openclaw/workspace/taskboard"

if [ ! -f "$MD_FILE" ]; then
  echo "[]" > "$JSON_FILE"
  exit 0
fi

# Parse the markdown into JSON using awk
node -e '
const fs = require("fs");
const md = fs.readFileSync("'"$MD_FILE"'", "utf8");

const lines = md.split("\n");
const sections = {
  backlog: "Backlog",
  todo: "To Do",
  in_progress: "In Progress",
  done: "Done"
};

const result = { backlog: [], todo: [], in_progress: [], done: [] };
let currentSection = null;

for (const line of lines) {
  const trimmed = line.trim();
  if (!trimmed) continue;

  // Detect section headers
  if (trimmed.startsWith("## ")) {
    const header = trimmed.replace("## ", "").replace(/^\*\*/,"").replace(/\*\*$/,"").trim();
    for (const [key, label] of Object.entries(sections)) {
      if (header.includes(label)) {
        currentSection = key;
        break;
      }
    }
    continue;
  }

  // Parse task line
  if (trimmed.startsWith("- [") && currentSection && result[currentSection]) {
    // Extract status
    const statusMatch = trimmed.match(/^-\s*\[([ >x])\]\s*/);
    const status = statusMatch ? statusMatch[1] : " ";
    let taskText = trimmed.replace(/^-\s*\[[ >x]\]\s*/, "").trim();

    // Skip comment-like, placeholder, and example lines
    if (taskText.startsWith("//") || taskText.startsWith("#")) continue;
    if (taskText.includes("acá")) continue;
    if (taskText.includes("YYYY-MM-DD") || taskText.includes("Título")) continue;
    if (taskText.startsWith("tarea") || taskText.startsWith("idea")) continue;

    // Determine priority from text
    let priority = "normal";
    if (taskText.includes("@urgente")) priority = "urgente";
    else if (taskText.includes("@importante")) priority = "importante";
    else if (taskText.includes("@baja")) priority = "baja";

    // Extract estimate
    let estimate = null;
    const estMatch = taskText.match(/@estimado:([\dhms]+)/);
    if (estMatch) estimate = estMatch[1];

    // Extract categories/tags
    const tags = (taskText.match(/#(\w+)/g) || []).map(t => t.replace("#", ""));

    // Extract created date
    let created = null;
    const dateMatch = taskText.match(/\(creada:\s*([^)]+)\)/);
    if (dateMatch) created = dateMatch[1].trim();

    // Clean the title
    let title = taskText
      .replace(/@urgente/g, "")
      .replace(/@importante/g, "")
      .replace(/@normal/g, "")
      .replace(/@baja/g, "")
      .replace(/@estimado:[\dhms]+/g, "")
      .replace(/#\w+/g, "")
      .replace(/\(creada:[^)]+\)/g, "")
      .replace(/\s+/g, " ")
      .trim();

    if (title) {
      result[currentSection].push({
        title,
        priority,
        tags: tags.length > 0 ? tags : [],
        created,
        estimate
      });
    }
  }
}

fs.writeFileSync("'"$JSON_FILE"'", JSON.stringify(result, null, 2));
'

# Check if anything changed
cd "$REPO_DIR"
git add -A
if git diff --cached --quiet; then
  exit 0
fi

git commit -m "taskboard: auto-sync $(date +%Y-%m-%d_%H:%M)" --quiet
git push origin main --quiet 2>&1 || echo "⚠️ Push failed (network?)"
