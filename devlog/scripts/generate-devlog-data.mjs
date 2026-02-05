#!/usr/bin/env node

import { promises as fs } from "node:fs";
import path from "node:path";
import process from "node:process";

const currentDir = process.cwd();
const repoRoot = path.resolve(currentDir, "..");
const logsDir = path.join(repoRoot, "codex-log");
const outputPath = path.join(currentDir, "src", "devlog-data.generated.ts");

const normalizeScalar = (value) => {
  const trimmed = value.trim();
  if (trimmed.startsWith("[") && trimmed.endsWith("]")) {
    return trimmed.slice(1, -1).trim();
  }

  return trimmed;
};

const escapeRegExp = (value) => {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
};

const readBullet = (content, label) => {
  const match = content.match(
    new RegExp(`^- ${escapeRegExp(label)}:\\s*(.+)$`, "m"),
  );
  return match ? normalizeScalar(match[1]) : null;
};

const readSection = (content, heading) => {
  const match = content.match(
    new RegExp(
      `^##\\s+${escapeRegExp(heading)}\\s*$([\\s\\S]*?)(?=^##\\s+|\\Z)`,
      "m",
    ),
  );
  return match ? match[1].trim() : "";
};

const countBulletsInSection = (content, heading) => {
  const section = readSection(content, heading);
  if (!section) {
    return 0;
  }

  return section
    .split("\n")
    .map((line) => line.trim())
    .filter((line) => line.startsWith("- ")).length;
};

const parseTimeSavedRangeMinutes = (rawValue) => {
  if (!rawValue) {
    return null;
  }

  const text = normalizeScalar(rawValue)
    .toLowerCase()
    .replace(/~/g, "")
    .replace(/\s+/g, " ")
    .trim();

  if (!text || /(none|unknown|n\/a)/.test(text)) {
    return null;
  }

  const toMinutes = (amount, unit) => {
    const asNumber = Number(amount);
    const factor = /(hour|hr)/.test(unit) ? 60 : 1;
    return Math.round(asNumber * factor);
  };

  const rangeMatch = text.match(
    /(\d+(?:\.\d+)?)\s*-\s*(\d+(?:\.\d+)?)\s*(hours?|hrs?|hr|minutes?|mins?|min)/,
  );
  if (rangeMatch) {
    return [
      toMinutes(rangeMatch[1], rangeMatch[3]),
      toMinutes(rangeMatch[2], rangeMatch[3]),
    ];
  }

  const singleMatch = text.match(
    /(\d+(?:\.\d+)?)\s*(hours?|hrs?|hr|minutes?|mins?|min)/,
  );
  if (singleMatch) {
    const minutes = toMinutes(singleMatch[1], singleMatch[2]);
    return [minutes, minutes];
  }

  return null;
};

const parseClockTime = (dateTime) => {
  const match = dateTime.match(/(\d{1,2}:\d{2})/);
  return match ? match[1] : "unknown";
};

const normalizeNarrativeLine = (value) => {
  return value.replace(/^\s*-\s*/, "").replace(/\s+/g, " ").trim();
};

const parseTools = (rawTools) => {
  if (!rawTools) {
    return [];
  }

  const parts = [];
  let current = "";
  let depth = 0;

  for (const char of rawTools) {
    if (char === "(") {
      depth += 1;
      current += char;
      continue;
    }

    if (char === ")") {
      depth = Math.max(0, depth - 1);
      current += char;
      continue;
    }

    if (char === "," && depth === 0) {
      parts.push(current);
      current = "";
      continue;
    }

    current += char;
  }

  if (current.trim().length > 0) {
    parts.push(current);
  }

  return parts
    .map((tool) => normalizeScalar(tool))
    .map((tool) => tool.trim())
    .filter(Boolean);
};

const inferHasTests = (testsRun) => {
  if (!testsRun) {
    return false;
  }

  const text = testsRun.toLowerCase();
  if (/(partial)/.test(text) && /(blocked|missing|not installed)/.test(text)) {
    return false;
  }

  if (/(none|not run|n\/a)/.test(text)) {
    return false;
  }

  return /(pass|ran|yes|succeed|executed|run)/.test(text);
};

const parseSession = async (fileName) => {
  const filePath = path.join(logsDir, fileName);
  const content = await fs.readFile(filePath, "utf8");

  const dateTime = readBullet(content, "Date/time") ?? "unknown";
  const primaryGoal = readBullet(content, "Primary goal") ?? "unknown";
  const toolsUsed = readBullet(content, "Tools used") ?? "";
  const testsRun = readBullet(content, "Tests run") ?? "unknown";
  const timeSaved = readBullet(content, "Time saved (estimate)");
  const beforeAfterRaw = readBullet(content, "Before/after");
  const bottlenecksRemovedRaw = readBullet(content, "Bottlenecks removed");
  const humanDecisionsRaw = readBullet(content, "Human decisions required");
  const beforeAfter = beforeAfterRaw
    ? normalizeNarrativeLine(beforeAfterRaw)
    : null;
  const bottlenecksRemoved = bottlenecksRemovedRaw
    ? normalizeNarrativeLine(bottlenecksRemovedRaw)
    : null;
  const humanDecisions = humanDecisionsRaw
    ? normalizeNarrativeLine(humanDecisionsRaw)
    : null;

  const primaryLower = primaryGoal.toLowerCase();
  const isRollbackSession =
    primaryLower.includes("revert") ||
    primaryLower.includes("rollback") ||
    primaryLower.includes("restore previous behavior");

  let challengeSummary = null;
  if (isRollbackSession) {
    challengeSummary = `Rollback: ${primaryGoal}`;
  } else if (bottlenecksRemovedRaw) {
    challengeSummary = `Bottleneck: ${bottlenecksRemoved}`;
  } else if (beforeAfterRaw) {
    challengeSummary = `Tradeoff: ${beforeAfter}`;
  } else if (humanDecisionsRaw) {
    challengeSummary = `Decision: ${humanDecisions}`;
  }

  return {
    id: fileName.replace(/\.md$/, ""),
    sourceFile: `codex-log/${fileName}`,
    dateTime,
    clockTime: parseClockTime(dateTime),
    primaryGoal,
    tools: parseTools(toolsUsed),
    testsRun,
    hasTests: inferHasTests(testsRun),
    timeSavedLabel: timeSaved ? normalizeScalar(timeSaved) : null,
    timeSavedRangeMinutes: parseTimeSavedRangeMinutes(timeSaved),
    codexActionCount: countBulletsInSection(content, "What Codex Did"),
    beforeAfter: beforeAfter ?? null,
    bottlenecksRemoved: bottlenecksRemoved ?? null,
    humanDecisions: humanDecisions ?? null,
    challengeSummary,
  };
};

const files = (await fs.readdir(logsDir))
  .filter((fileName) => fileName.endsWith(".md"))
  .sort();

const sessions = await Promise.all(files.map(parseSession));

const testedSessionCount = sessions.filter((session) => session.hasTests).length;
const uniqueTools = [...new Set(sessions.flatMap((session) => session.tools))].sort(
  (a, b) => a.localeCompare(b),
);
const totalCodexActions = sessions.reduce(
  (total, session) => total + session.codexActionCount,
  0,
);
const challengeSessionCount = sessions.filter(
  (session) => session.challengeSummary !== null,
).length;

const totalTimeRangeMinutes = sessions.reduce(
  (range, session) => {
    if (!session.timeSavedRangeMinutes) {
      return range;
    }

    return [
      range[0] + session.timeSavedRangeMinutes[0],
      range[1] + session.timeSavedRangeMinutes[1],
    ];
  },
  [0, 0],
);

const summary = {
  sessionCount: sessions.length,
  testedSessionCount,
  challengeSessionCount,
  uniqueTools,
  totalCodexActions,
  totalTimeRangeMinutes,
  firstSession: sessions[0]?.clockTime ?? "unknown",
  lastSession: sessions.at(-1)?.clockTime ?? "unknown",
};

const generated = `/* eslint-disable */
/**
 * Generated by \`npm run sync:data\`.
 * Source: ../codex-log/*.md
 */

export type DevlogSession = {
  id: string;
  sourceFile: string;
  dateTime: string;
  clockTime: string;
  primaryGoal: string;
  tools: string[];
  testsRun: string;
  hasTests: boolean;
  timeSavedLabel: string | null;
  timeSavedRangeMinutes: [number, number] | null;
  codexActionCount: number;
  beforeAfter: string | null;
  bottlenecksRemoved: string | null;
  humanDecisions: string | null;
  challengeSummary: string | null;
};

export type DevlogSummary = {
  sessionCount: number;
  testedSessionCount: number;
  challengeSessionCount: number;
  uniqueTools: string[];
  totalCodexActions: number;
  totalTimeRangeMinutes: [number, number];
  firstSession: string;
  lastSession: string;
};

export const devlogSessions: DevlogSession[] = ${JSON.stringify(sessions, null, 2)};

export const devlogSummary: DevlogSummary = ${JSON.stringify(summary, null, 2)};
`;

await fs.writeFile(outputPath, generated, "utf8");

console.log(
  `Generated ${path.relative(currentDir, outputPath)} from ${sessions.length} devlog entries.`,
);
