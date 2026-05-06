// Patch MCP SDK inputSchema.type validation for Zod v4 compatibility.
// Problem: z.literal("object") rejects tools that omit inputSchema.type
// (e.g., legacy MCP servers using SDK 1.0.1 omit inputSchema.type).
// Fix: z.literal("object").default("object") — defaults missing type to "object".
//
// Affects: node_modules/@modelcontextprotocol/sdk/dist/{cjs,esm}/types.js
// Upstream: MCPhub SDK @modelcontextprotocol/sdk@1.27.1 + zod@3.25.76

const fs = require("fs");
const path = require("path");

const pattern = /type: z\.literal\('object'\),/g;
const replacement = 'type: z.literal("object").default("object"),';

const targets = [
  "node_modules/@modelcontextprotocol/sdk/dist/cjs/types.js",
  "node_modules/@modelcontextprotocol/sdk/dist/esm/types.js",
];

let patched = 0;
for (const rel of targets) {
  const file = path.resolve("/app", rel);
  if (!fs.existsSync(file)) continue;

  const src = fs.readFileSync(file, "utf8");
  if (src.includes('.default("object")')) {
    continue; // already patched
  }

  const out = src.replace(pattern, replacement);
  if (out !== src) {
    fs.writeFileSync(file, out);
    patched++;
  }
}

if (patched > 0) {
  console.log(`[patch-sdk-schema] Patched ${patched} file(s): inputSchema.type default("object")`);
} else {
  console.log("[patch-sdk-schema] Already patched or no files to patch");
}
