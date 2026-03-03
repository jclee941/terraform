#!/usr/bin/env node
// Strips _placeholder from MCP tool arguments in mcpService.js at container startup.
// Workaround for: https://github.com/samanhappy/mcphub/pull/654
// Remove this file after PR #654 merges and mcphub image version is bumped.

"use strict";

const fs = require("fs");
const MCPSERVICE = "/app/dist/services/mcpService.js";

try {
  if (!fs.existsSync(MCPSERVICE)) {
    console.log("[patch] mcpService.js not found, skipping");
    process.exit(0);
  }

  let code = fs.readFileSync(MCPSERVICE, "utf8");

  if (code.includes("sanitizeToolArguments")) {
    console.log("[patch] Already applied, skipping");
    process.exit(0);
  }

  // Inject sanitize function at top of file
  const sanitizeFn = [
    "// [PATCH] Strip _placeholder from MCP tool args — github.com/samanhappy/mcphub/pull/654",
    "function sanitizeToolArguments(args) {",
    '  if (!args || typeof args !== "object") return args;',
    "  const clean = { ...args };",
    "  delete clean._placeholder;",
    "  return Object.keys(clean).length === 0 ? undefined : clean;",
    "}",
    "",
  ].join("\n");

  code = sanitizeFn + code;

  // Wrap argument-passing in callTool path (only finalArgs — toolArgs appears in destructuring)
  code = code.replace(
    /arguments:\s*finalArgs\b/g,
    "arguments: sanitizeToolArguments(finalArgs)"
  );

  fs.writeFileSync(MCPSERVICE, code);
  console.log("[patch] _placeholder sanitization applied to mcpService.js");
} catch (err) {
  // Non-fatal — don't block container startup
  console.error("[patch] Failed (non-fatal):", err.message);
  process.exit(0);
}
