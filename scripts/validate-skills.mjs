#!/usr/bin/env node
// validate-skills.mjs
//
// Validates the structure and frontmatter of every skill in skills/.
// Plain Node ESM, no dependencies. Run with:
//
//   node scripts/validate-skills.mjs
//
// Exits 0 on success, 1 with a list of problems otherwise.

import { readdirSync, statSync, existsSync, readFileSync } from "node:fs";
import { join, basename } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = fileURLToPath(new URL(".", import.meta.url));
const repoRoot = join(__dirname, "..");
const skillsRoot = join(repoRoot, "skills");

const problems = [];
let validatedCount = 0;

/**
 * Parses a minimal YAML frontmatter block using a hand-rolled key/value
 * line parser (intentionally not a full YAML parser — no dependency).
 *
 * Supports:
 *  - plain scalar values:      key: value
 *  - single-quoted values:     key: 'value'
 *  - double-quoted values:     key: "value"
 *  - block scalars (> or |) with the value continued on indented
 *    following lines, terminated by a line at or below the key's
 *    original indentation (or end of frontmatter).
 *
 * Returns a plain object mapping key -> string value.
 */
function parseFrontmatter(lines) {
  const result = {};
  let i = 0;

  while (i < lines.length) {
    const rawLine = lines[i];

    // Skip blank lines and comments between top-level keys.
    if (rawLine.trim() === "" || rawLine.trim().startsWith("#")) {
      i++;
      continue;
    }

    const keyMatch = rawLine.match(/^([A-Za-z0-9_-]+):(\s*)(.*)$/);
    if (!keyMatch) {
      // Not a recognizable "key:" line at the top level; skip it.
      i++;
      continue;
    }

    const key = keyMatch[1];
    const rest = keyMatch[3];

    if (rest === "" || rest === undefined) {
      // No inline value: either a block scalar follows, or the value is
      // simply empty. Peek at following indented lines.
      i++;
      const blockLines = [];
      while (i < lines.length) {
        const next = lines[i];
        if (next.trim() === "") {
          blockLines.push("");
          i++;
          continue;
        }
        const indentMatch = next.match(/^(\s+)\S/);
        if (indentMatch) {
          blockLines.push(next.slice(indentMatch[1].length));
          i++;
        } else {
          break;
        }
      }
      result[key] = blockLines.join("\n").trim();
      continue;
    }

    const trimmedRest = rest.trim();

    if (trimmedRest === ">" || trimmedRest === "|") {
      // Block scalar: gather subsequent indented lines.
      i++;
      const blockLines = [];
      while (i < lines.length) {
        const next = lines[i];
        if (next.trim() === "") {
          blockLines.push("");
          i++;
          continue;
        }
        const indentMatch = next.match(/^(\s+)\S/);
        if (indentMatch) {
          blockLines.push(next.slice(indentMatch[1].length));
          i++;
        } else {
          break;
        }
      }
      result[key] =
        trimmedRest === ">"
          ? blockLines.join(" ").replace(/\s+/g, " ").trim()
          : blockLines.join("\n").trim();
      continue;
    }

    if (
      trimmedRest.length >= 2 &&
      trimmedRest.startsWith("'") &&
      trimmedRest.endsWith("'")
    ) {
      result[key] = trimmedRest.slice(1, -1);
    } else if (
      trimmedRest.length >= 2 &&
      trimmedRest.startsWith('"') &&
      trimmedRest.endsWith('"')
    ) {
      result[key] = trimmedRest.slice(1, -1);
    } else {
      result[key] = trimmedRest;
    }

    i++;
  }

  return result;
}

function extractFrontmatterBlock(content, filePath) {
  const lines = content.split(/\r?\n/);

  if (lines[0] !== "---") {
    problems.push(`${filePath}: does not begin with a '---' frontmatter block`);
    return null;
  }

  let closeIndex = -1;
  for (let i = 1; i < lines.length; i++) {
    if (lines[i] === "---") {
      closeIndex = i;
      break;
    }
  }

  if (closeIndex === -1) {
    problems.push(`${filePath}: frontmatter block is never closed with '---'`);
    return null;
  }

  return lines.slice(1, closeIndex);
}

function isDirectory(path) {
  try {
    return statSync(path).isDirectory();
  } catch {
    return false;
  }
}

if (!existsSync(skillsRoot)) {
  console.log("0 skill(s) validated, 0 problem(s)");
  process.exit(0);
}

const topLevelEntries = readdirSync(skillsRoot, { withFileTypes: true });

for (const entry of topLevelEntries) {
  const entryPath = join(skillsRoot, entry.name);
  if (!entry.isDirectory()) {
    problems.push(
      `${entryPath}: stray file directly under skills/ (only category directories are allowed)`
    );
    continue;
  }

  const categoryDir = entryPath;
  const categoryName = entry.name;
  const categoryEntries = readdirSync(categoryDir, { withFileTypes: true });

  for (const skillEntry of categoryEntries) {
    const skillDirPath = join(categoryDir, skillEntry.name);

    if (!skillEntry.isDirectory()) {
      problems.push(
        `${skillDirPath}: stray file directly under skills/${categoryName}/ (every skill must be at skills/<category>/<name>/SKILL.md)`
      );
      continue;
    }

    validatedCount++;

    const skillName = skillEntry.name;
    const skillMdPath = join(skillDirPath, "SKILL.md");
    const openaiYamlPath = join(skillDirPath, "agents", "openai.yaml");

    if (!existsSync(skillMdPath) || !statSync(skillMdPath).isFile()) {
      problems.push(`${skillMdPath}: missing SKILL.md`);
      continue;
    }

    if (!existsSync(openaiYamlPath) || !statSync(openaiYamlPath).isFile()) {
      problems.push(`${openaiYamlPath}: missing agents/openai.yaml`);
    }

    const content = readFileSync(skillMdPath, "utf8");
    const frontmatterLines = extractFrontmatterBlock(content, skillMdPath);

    if (frontmatterLines === null) {
      continue;
    }

    const frontmatter = parseFrontmatter(frontmatterLines);

    const name = frontmatter.name;
    const description = frontmatter.description;

    if (!name || name.trim() === "") {
      problems.push(`${skillMdPath}: frontmatter 'name' is missing or empty`);
    } else if (name !== skillName) {
      problems.push(
        `${skillMdPath}: frontmatter 'name' ("${name}") does not match containing directory name ("${skillName}")`
      );
    }

    if (!description || description.trim() === "") {
      problems.push(`${skillMdPath}: frontmatter 'description' is missing or empty`);
    }

    if (
      Object.prototype.hasOwnProperty.call(frontmatter, "disable-model-invocation")
    ) {
      const value = frontmatter["disable-model-invocation"];
      if (value !== "true") {
        problems.push(
          `${skillMdPath}: frontmatter 'disable-model-invocation' must be exactly "true" (found "${value}")`
        );
      }
    }
  }
}

for (const problem of problems) {
  console.log(problem);
}

console.log(`${validatedCount} skill(s) validated, ${problems.length} problem(s)`);

process.exit(problems.length > 0 ? 1 : 0);
